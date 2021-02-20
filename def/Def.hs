{-# Language MagicHash #-}
{-# Language UnboxedSums #-}
{-# Language UnboxedTuples #-}
{-# Language TypeFamilies #-}
{-# Language PolyKinds #-}
{-# Language DataKinds #-}
{-# Language PatternSynonyms #-}
{-# Language RankNTypes #-}
{-# Language NoImplicitPrelude #-}
{-# Language RebindableSyntax #-}
{-# Language ImportQualifiedPost #-}
{-# Language TypeSynonymInstances #-}
{-# Language FlexibleContexts #-}

module Def where

import Unlifted.Internal.Class
import Unlifted.Internal.List
import Unlifted.Internal.Maybe
import GHC.Types
import Prelude (otherwise, not, (++), ShowS, (.), showString, showParen,($), (&&), (||))
import Prelude qualified
import System.IO qualified as IO

import Rep

instance EqRep Rep where
  eqDef x y = not (x /= y)
  neDef x y = not (x == y)

instance OrdRep Rep where
  compareDef x y
    | x == y = EQ
    | x <= y = LT
    | otherwise = GT

  ltDef x y = case compare x y of LT -> True;  _ -> False
  leDef x y = case compare x y of GT -> False; _ -> True
  gtDef x y = case compare x y of GT -> True;  _ -> False
  geDef x y = case compare x y of LT -> False; _ -> True

  maxDef x y
    | x <= y = y
    | otherwise = x

  minDef x y
    | x <= y = x
    | otherwise = y

instance NumRep Rep where 
  negateDef a = 0 - a
  minusDef a b = a + negate b

data ListDef (a :: TYPE Rep)
  = Nil
  | a :# ListDef a

infixr 5 :#

instance ListRep Rep where
  type List = ListDef
  cons# = (:#) 
  nil# = Nil
  uncons# (a :# as) = Maybe# (# | (# a, as #) #)
  uncons# Nil = Maybe# (# (##) | #)

instance Eq a => Prelude.Eq (ListDef a) where
  Nil == Nil = True
  a :# as == b :# bs = a == b && as == bs
  _ == _ = False

  Nil /= Nil = True
  a :# as /= b :# bs = a /= b || as /= bs
  _ /= _ = False

instance Ord a => Prelude.Ord (ListDef a) where
  compare Nil Nil = EQ
  compare Nil (:#){} = LT
  compare (:#){} Nil = GT
  compare (a:#as) (b:#bs) = compare a b <> compare as bs

instance Show a => Prelude.Show (ListDef a) where
  showsPrec _ = showList

data MaybeDef (a :: TYPE Rep)
  = Nothing
  | Just a

instance Eq a => Prelude.Eq (MaybeDef a) where
  Nothing == Nothing = True
  Just a == Just b = a == b
  _ == _ = False
  
instance Ord a => Prelude.Ord (MaybeDef a) where
  compare Nothing  Nothing = EQ
  compare Nothing  Just{} = LT
  compare Just{}   Nothing = GT
  compare (Just a) (Just b) = compare a b

instance Show a => Prelude.Show (MaybeDef a) where
  showsPrec _ Nothing = showString "Nothing"
  showsPrec d (Just a) = showParen (d < 11) $ showString "Just " . showsPrec d a

instance MaybeRep Rep where
  type Maybe = MaybeDef
  nothing = Nothing
  just = Just
  maybe n _ Nothing = n
  maybe _ j (Just a) = j a

instance MaybeRep# Rep where
  nothing# = Maybe# (# (##) | #)
  just# a = Maybe# (# | a #)
  maybe# n _ (Maybe# (# (##) | #)) = n
  maybe# _ j (Maybe# (# | a #)) = j a

pattern Nothing# :: forall (a :: TYPE Rep). Maybe# a
pattern Nothing# = Maybe# (# (##) | #)

pattern Just# :: forall (a :: TYPE Rep). a -> Maybe# a
pattern Just# a = Maybe# (# | a #)

-- this instance will probably not fire without a lot of help, because that body condition is harsh
-- TODO: split ShowList into a separate class, even if this breaks compat with base
instance (ListRep ('SumRep '[ 'TupleRep '[], Rep ]), Show a) => Show (Maybe# (a :: TYPE Rep)) where
  showsPrec _ Nothing# = showString "Nothing#"
  showsPrec d (Just# a) = showParen (d < 11) $ showString "Just# " . showsPrec d a
  show x = shows x ""
  showList = go shows where
    go :: forall (a :: TYPE Rep). (Maybe# a -> ShowS) -> List (Maybe# a) -> ShowS
    go showx l s = case uncons# l of
      Maybe# (# (##) | #) -> "[]" ++ s
      Maybe# (# | (# x, xs #) #) -> '[' : showx x (showl xs)
        where 
          showl l' = case uncons# l' of
            Maybe# (# (##) | #) -> ']' : s
            Maybe# (# | (# y, ys #) #) -> ',' : showx y (showl ys)

{-# complete Nothing#, Just# :: Maybe# #-}

instance ShowRep Rep where
  showsPrecDef _ x s = show x ++ s
  showDef x          = shows x ""
  showListDef ls   s = showList__ shows ls s

showList__ :: forall (a :: TYPE Rep). (a -> ShowS) -> List a -> ShowS
showList__ _     Nil       s = "[]" ++ s
showList__ showx (x :# xs) s = '[' : showx x (showl xs)
  where
    showl Nil       = ']' : s
    showl (y :# ys) = ',' : showx y (showl ys)

instance PrintRep Rep where
  hPrint h x = IO.hPutStrLn h (show x)