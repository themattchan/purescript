-- |
-- Dump the core functional representation in JSON format for consumption
-- by third-party code generators
--
module Language.PureScript.CoreFn.ToJSON
  ( moduleToJSON
  ) where

import Prelude.Compat

import Data.Aeson
import Data.Text (pack)

import Language.PureScript.AST.Literals
import Language.PureScript.CoreFn
import Language.PureScript.Names

literalToJSON :: (a -> Value) -> Literal a -> Value
literalToJSON _ (NumericLiteral (Left n)) = toJSON ("IntLiteral", n)
literalToJSON _ (NumericLiteral (Right n)) = toJSON ("NumberLiteral", n)
literalToJSON _ (StringLiteral s) = toJSON ("StringLiteral", s)
literalToJSON _ (CharLiteral c) = toJSON ("CharLiteral", c)
literalToJSON _ (BooleanLiteral b) = toJSON ("BooleanLiteral", b)
literalToJSON t (ArrayLiteral xs) = toJSON ("ArrayLiteral", map t xs)
literalToJSON t (ObjectLiteral xs) = toJSON ("ObjectLiteral", recordToJSON t xs)

identToJSON :: Ident -> Value
identToJSON = toJSON . runIdent

qualifiedToJSON :: (a -> Value) -> Qualified a -> Value
qualifiedToJSON t (Qualified Nothing i) = t i
qualifiedToJSON t (Qualified (Just mn) i) = toJSON [moduleNameToJSON mn, t i]

moduleNameToJSON :: ModuleName -> Value
moduleNameToJSON = toJSON . runModuleName

properNameToJSON :: ProperName a -> Value
properNameToJSON (ProperName n) = toJSON n

moduleToJSON :: Module a -> Value
moduleToJSON m = object [ pack "imports"  .= map (moduleNameToJSON . snd) (moduleImports m)
                        , pack "exports"  .= map identToJSON (moduleExports m)
                        , pack "foreign"  .= map (identToJSON . fst) (moduleForeign m)
                        , pack "decls"    .= recordToJSON exprToJSON (foldMap fromBind (moduleDecls m))
                        ]

fromBind :: Bind a -> [(String, Expr a)]
fromBind (NonRec _ n e) = [(runIdent n, e)]
fromBind (Rec bs) = map (\((_, n), e) -> (runIdent n, e)) bs

recordToJSON :: (a -> Value) -> [(String, a)] -> Value
recordToJSON f = object . map (\(label, a) -> pack label .= f a)

exprToJSON :: Expr a -> Value
exprToJSON (Var _ i)              = qualifiedToJSON identToJSON i
exprToJSON (Literal _ l)          = toJSON ( "Literal"
                                           , literalToJSON (exprToJSON) l
                                           )
exprToJSON (Constructor _ d c is) = toJSON ( "Constructor"
                                           , properNameToJSON d
                                           , properNameToJSON c
                                           , map identToJSON is
                                           )
exprToJSON (Accessor _ f r)       = toJSON ( "Accessor"
                                           , f
                                           , exprToJSON r
                                           )
exprToJSON (ObjectUpdate _ r fs)  = toJSON ( "ObjectUpdate"
                                           , exprToJSON r
                                           , recordToJSON exprToJSON fs
                                           )
exprToJSON (Abs _ p b)            = toJSON ( "Abs"
                                           , identToJSON p
                                           , exprToJSON b
                                           )
exprToJSON (App _ f x)            = toJSON ( "App"
                                           , exprToJSON f
                                           , exprToJSON x
                                           )
exprToJSON (Case _ ss cs)         = toJSON ( "Case"
                                           , map exprToJSON ss
                                           , map caseAlternativeToJSON cs
                                           )
exprToJSON (Let _ bs e)           = toJSON ( "Let"
                                           , recordToJSON exprToJSON (foldMap fromBind bs)
                                           , exprToJSON e
                                           )

caseAlternativeToJSON :: CaseAlternative a -> Value
caseAlternativeToJSON (CaseAlternative bs r') =
  toJSON [ toJSON (map binderToJSON bs)
         , case r' of
             Left rs -> toJSON $ map (\(g, e) -> (exprToJSON g, exprToJSON e)) rs
             Right r -> exprToJSON r
         ]

binderToJSON :: Binder a -> Value
binderToJSON (NullBinder _)               = toJSON "NullBinder"
binderToJSON (LiteralBinder _ l)          = toJSON ( "LiteralBinder"
                                                   , literalToJSON binderToJSON l
                                                   )
binderToJSON (VarBinder _ v)              = toJSON ( "VarBinder"
                                                   , identToJSON v
                                                   )
binderToJSON (ConstructorBinder _ d c bs) = toJSON ( "ConstructorBinder"
                                                   , qualifiedToJSON properNameToJSON d
                                                   , qualifiedToJSON properNameToJSON c
                                                   , map binderToJSON bs
                                                   )
binderToJSON (NamedBinder _ n b)          = toJSON ( "NamedBinder"
                                                   , identToJSON n
                                                   , binderToJSON b
                                                   )
