module Deque.Lazy
(
  Deque,
  fromConsAndSnocLists,
  cons,
  snoc,
  reverse,
  shiftLeft,
  shiftRight,
  filter,
  takeWhile,
  dropWhile,
  uncons,
  unsnoc,
  null,
  head,
  last,
  tail,
  init,
)
where

import Control.Monad (fail)
import Deque.Prelude hiding (tail, init, last, head, null, dropWhile, takeWhile, reverse, filter)
import qualified Data.List as List
import qualified Deque.Prelude as Prelude

-- |
-- Lazy double-ended queue (aka Dequeue or Deque) based on head-tail linked list.
-- Can be cycled. See `shiftLeft` and `shiftRight`.
-- 
-- The typical `toList` and `fromList` conversions are provided by means of
-- the `Foldable` and `IsList` instances.
data Deque a = Deque {-# UNPACK #-} ![a] {-# UNPACK #-} ![a]

-- |
-- /O(1)/.
-- Construct from cons and snoc lists.
fromConsAndSnocLists :: [a] -> [a] -> Deque a
fromConsAndSnocLists consList snocList = Deque snocList consList

-- |
-- /O(n)/.
-- Leave only the elements satisfying the predicate.
filter :: (a -> Bool) -> Deque a -> Deque a
filter predicate (Deque snocList consList) = Deque (List.filter predicate snocList) (List.filter predicate consList)

-- |
-- /O(n)/.
-- Leave only the first elements satisfying the predicate.
takeWhile :: (a -> Bool) -> Deque a -> Deque a
takeWhile predicate (Deque snocList consList) =
  let
    newConsList = List.foldr
      (\ a nextState -> if predicate a
        then a : nextState
        else [])
      (List.takeWhile predicate (List.reverse snocList))
      consList
    in Deque [] newConsList

-- |
-- /O(n)/.
-- Drop the first elements satisfying the predicate.
dropWhile :: (a -> Bool) -> Deque a -> Deque a
dropWhile predicate (Deque snocList consList) =
  let
    newConsList = List.dropWhile predicate consList
    in case newConsList of
      [] -> Deque [] (List.dropWhile predicate (List.reverse snocList))
      _ -> Deque snocList newConsList

-- |
-- /O(1)/, occasionally /O(n)/.
--
-- @
-- λ toList . shiftLeft $ fromList [1,2,3]
-- [2,3,1]
-- @
shiftLeft :: Deque a -> Deque a
shiftLeft deque =
  maybe deque (uncurry snoc) (uncons deque)

-- |
-- /O(1)/, occasionally /O(n)/.
--
-- @
-- λ toList . shiftRight $ fromList [1,2,3]
-- [3,1,2]
-- @
shiftRight :: Deque a -> Deque a
shiftRight deque =
  maybe deque (uncurry cons) (unsnoc deque)

-- |
-- /O(1)/.
-- Prepend an element.
cons :: a -> Deque a -> Deque a
cons a (Deque snocList consList) =
  Deque snocList (a : consList)

-- |
-- /O(1)/.
-- Append an element.
snoc :: a -> Deque a -> Deque a
snoc a (Deque snocList consList) =
  Deque (a : snocList) consList

-- |
-- /O(1)/, occasionally /O(n)/.
uncons :: Deque a -> Maybe (a, Deque a)
uncons (Deque snocList consList) =
  case consList of
    head : tail ->
      Just (head, Deque snocList tail)
    _ ->
      case Prelude.reverse snocList of
        head : tail ->
          Just (head, Deque [] tail)
        _ ->
          Nothing

-- |
-- /O(1)/, occasionally /O(n)/.
unsnoc :: Deque a -> Maybe (a, Deque a)
unsnoc (Deque snocList consList) =
  case snocList of
    head : tail ->
      Just (head, Deque tail consList)
    _ ->
      case Prelude.reverse consList of
        head : tail ->
          Just (head, Deque tail [])
        _ ->
          Nothing

-- |
-- /O(n)/.
prepend :: Deque a -> Deque a -> Deque a
prepend (Deque snocList1 consList1) (Deque snocList2 consList2) =
  Deque snocList3 consList3
  where
    snocList3 =
      snocList2 ++ foldl' (flip (:)) snocList1 consList2
    consList3 =
      consList1

-- |
-- /O(1)/.
reverse :: Deque a -> Deque a
reverse (Deque snocList consList) =
  Deque consList snocList

-- |
-- /O(1)/. 
null :: Deque a -> Bool
null (Deque snocList consList) =
  List.null snocList && List.null consList

-- |
-- /O(1)/, occasionally /O(n)/.
head :: Deque a -> Maybe a
head =
  fmap fst . uncons

-- |
-- /O(1)/, occasionally /O(n)/.
tail :: Deque a -> Deque a
tail =
  fromMaybe <$> id <*> fmap snd . uncons

-- |
-- /O(1)/, occasionally /O(n)/.
init :: Deque a -> Deque a
init =
  fromMaybe <$> id <*> fmap snd . unsnoc

-- |
-- /O(1)/, occasionally /O(n)/.
last :: Deque a -> Maybe a
last =
  fmap fst . unsnoc


instance Eq a => Eq (Deque a) where
  (==) a b = toList a == toList b

instance Show a => Show (Deque a) where
  show = showString "fromList " . show . toList

instance Semigroup (Deque a) where
  (<>) = prepend

instance Monoid (Deque a) where
  mempty =
    Deque [] []
  mappend =
    (<>)

instance Foldable Deque where
  foldr step init (Deque snocList consList) =
    foldr step (foldl' (flip step) init snocList) consList
  foldl' step init (Deque snocList consList) =
    foldr' (flip step) (foldl' step init consList) snocList

instance Traversable Deque where
  traverse f (Deque ss cs) =
    (\cs' ss' -> Deque (Prelude.reverse ss') cs') <$> traverse f cs <*> traverse f (Prelude.reverse ss)

deriving instance Functor Deque

instance Applicative Deque where
  pure a =
    Deque [] [a]
  fs <*> as =
    fromList (toList fs <*> toList as)

instance Monad Deque where
  return =
    pure
  m >>= f =
    fromList (toList m >>= toList . f)
  fail =
    const mempty

instance Alternative Deque where
  empty =
    mempty
  (<|>) =
    mappend

instance MonadPlus Deque where
  mzero =
    empty
  mplus =
    (<|>)

instance MonadFail Deque where
  fail = const mempty

-- |
-- /O(1)/.
instance IsList (Deque a) where
  type Item (Deque a) = a
  fromList = Deque []
  toList (Deque snocList consList) = consList <> List.reverse snocList
  