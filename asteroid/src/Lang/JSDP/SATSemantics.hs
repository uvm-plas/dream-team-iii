module Lang.JSDP.SATSemantics where

import Lib

import Lang.JSDP.Syntax

-- interpret e env
-- + assume that all free variables in e are in keys(env)
interpret ∷ Exp → 𝕊 ⇰ 𝔹 → 𝑂 𝔹
interpret e env = case e of
 Lit b -> return b
 Var x -> env # x
 Join x y -> do
   bx ← interpret x env 
   by ← interpret y env
   return $ bx ⩔ by
 DProd x y -> do
   bx ← interpret x env 
   by ← interpret y env
   return $ bx ⩓ by
