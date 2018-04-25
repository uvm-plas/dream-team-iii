module Lang.JSDPC.Equivalence where

import Lib

import Lang.JSDPC.Syntax

-- e.g., if(x){if(y){a}{b}}{if(z){d}{e}}
--          ^
--      no nesting
--
-- in constructor form
-- Link "x" (Link "y" (Leaf "a") (Leaf "b")) (Link "z" (Leaf "d") (Leaf "e"))
--
-- INVARIANT
-- The variables mentioned in the link chain should be in strictly ascending
-- order, that is:
-- 
--     if(x){if(y){a}{b}}{if(z){d}{e}}
--
-- is a valid IfChain because x < y and x < z. The following IfChain is
-- therefore invalid:
--
--     if(y){if(x){a}{b}}{if(z){d}{e}}
--
-- because y ≮ z
--
-- also, this chain is not valid either:
--
--     if(x){if(y){a}{b}}{if(x){d}{e}}
--
-- because x ≮ x

--data IfChain = 
--    Leaf 𝕊
--  | Link 𝕊 IfChain IfChain
--  deriving (Ord, Eq, Show)

type LeafData = 𝑃 (𝐿 𝕊) 
data NF = 
    Leaf LeafData
  -- if (x){y}{z} 
  -- where x is a LeafData (call unnormalizeLeafData
  -- and y and z are NF (call unnormalize recursively)
  -- so you'll get xun, yun, zun, and you just build (If xun yun zun)
  | Link LeafData NF NF 
  deriving (Eq,Ord,Show)

--instance Ord IfChain where
  --compare _ _ = LT  

-- !! complete unnormalize
-- NF is a "sum of products of if-chains" representation.
--type NF = 𝑃 (𝐿 IfChain)

unnormalizeLeafData ∷ LeafData → Exp
unnormalizeLeafData sps = 
  foldr𝐿 (Lit False) Join
  $ map𝐿 (foldr𝐿 (Lit True) DProd)
  $ map𝐿 (map𝐿 Var) 
  $ list𝑃 sps
  
-- !! assignment: write down some non-trivial examples to normalize and unnormalize...
unnormalize ∷ NF → Exp
unnormalize (Leaf ld) = unnormalizeLeafData ld
unnormalize (Link lf nf1 nf2) = If (unnormalizeLeafData lf) (unnormalize nf1) (unnormalize nf2)

balanceNF ∷ NF -> NF
balanceNF (Leaf x) = Leaf x
balanceNF (Link x y z) = balanceLink x y z

moveFirstLinkUp ∷ LeafData -> NF -> NF -> NF
moveFirstLinkUp x (Link a b c) y = Link a (Link x b y) (Link x c y)

moveSecondLinkUp ∷ LeafData -> NF -> NF -> NF
moveSecondLinkUp x y (Link k l m) = Link k (Link x y l) (Link x y m)

-- if(y){if(x){a}{b}}{c} balances to if(x){if(y){a}{c}}{if(y){b}{c}}
-- if(y){a}{if(x){b}{c}} balances to if(x){if(y){a}{b}}{if(y){a}{c}}

balanceLink ∷ LeafData → NF → NF → NF
balanceLink x (Leaf y) (Leaf z) = Link x (Leaf y) (Leaf z)
balanceLink x (Link a b c) (Leaf y) = 
  let first = balanceLink a b c in
  case first of
  Link d e f -> case (d > x) of
    True -> moveFirstLinkUp x first (Leaf y)
    False -> Link x first (Leaf y)

balanceLink x (Leaf y) (Link a b c) = 
  let second = balanceLink a b c in
  case second of 
  Link d e f -> case (d > x) of
    True -> moveSecondLinkUp x (Leaf y) second
    False -> Link x (Leaf y) second

balanceLink x (Link a b c) (Link d e f) = 
  -- David thinks this step is unnecessary
  let temp = Link x (balanceLink a b c) (balanceLink d e f) in
  case temp of
  Link x (Link g h i) (Link k l m) -> case (x > g) of      --TODO: better way than case?
    False -> case (x > k) of
      False -> Link x (Link g h i) (Link k l m)
      True -> moveSecondLinkUp x (Link g h i) (Link k l m)
    True -> case (g > k) of
      False -> moveFirstLinkUp x (Link g h i) (Link k l m)
      True -> moveSecondLinkUp x (Link g h i) (Link k l m)

ddBalanceLink ∷ LeafData → NF → NF → NF
ddBalanceLink x (Leaf y) (Leaf z) = Link x (Leaf y) (Leaf z)
ddBalanceLink x (Link a b c) (Leaf y) = 
  -- we don't need this step
  let first = ddBalanceLink a b c in
  case first of
  Link d e f -> case (d > x) of
    True -> moveFirstLinkUp x first (Leaf y)
    False -> Link x first (Leaf y)

ddBalanceLink x (Leaf y) (Link a b c) = 
  let second = ddBalanceLink a b c in
  case second of 
  Link d e f -> case (d > x) of
    True -> moveSecondLinkUp x (Leaf y) second
    False -> Link x (Leaf y) second

-- !! homework, finish this pretty version
-- if(x){if(a){b}{c}}{if(d){e}{f}}

ddBalanceLink x (Link a b c) (Link d e f) = 
  case (x ⋚ a,x ⋚ d,a ⋚ d) of
    (LT,_,LT) -> 
      -- we have x < a < d
      Link x (Link a b c) (Link d e f)
    (_,GT,LT) ->
      -- we have a < d < x
      -- we want if(a)
      --           { if(d){ if(x){b}{e} }{ if(x){b}{f} } }
      --           { if(d){ if(x){c}{e} }{ if(x){c}{f} } }
      Link a (Link d (Link x b e) (Link x b f))
             (Link d (Link x c e) (Link x c f))
    (LT,GT,_) ->
      -- we have d < x < a
      Link d (Link x (Link a b c) e)
             (Link x (Link a b c) f)
    (GT,_,GT) ->
      -- we have d < a < x
      Link d (Link a (Link x b e) (Link x c e))
             (Link a (Link x b f) (Link x c f))
    (GT,LT,_) -> undefined
      -- we have a < x < d
      Link a (Link x b (Link d e f))
             (Link x c (Link d e f))
    (_,LT,GT) ->
      -- we have x < d < a
      Link x (Link a b c) (Link d e f)

  -- Link x (Link g h i) (Link k l m) -> case (x > g) of
  --   False -> case (x > k) of
  --     False -> Link x (Link g h i) (Link k l m)
  --     True -> moveSecondLinkUp x (Link g h i) (Link k l m)
  --   True -> case (g > k) of
  --     False -> moveFirstLinkUp x (Link g h i) (Link k l m)
  --     True -> moveSecondLinkUp x (Link g h i) (Link k l m)

ramyCleanBalanceLink ∷ LeafData → NF → NF → NF
ramyCleanBalanceLink x (Leaf y) (Leaf z) = Link x (Leaf y) (Leaf z)
ramyCleanBalanceLink x (Link a b c) (Leaf y) = 
    case (a < x) of
    True  -> Link a (Link x b (Leaf y)) (Link x c (Leaf y))
    False -> Link x (Link a b c) (Leaf y)

ramyCleanBalanceLink x (Leaf y) (Link a b c) = 
    case (a < x) of
    True ->  Link a (Link x (Leaf y) b) (Link x (Leaf y) c)
    False -> Link x (Leaf y) (Link a b c)

ramyCleanBalanceLink x (Link a b c) (Link d e f) = 
  case (x ⋚ a,x ⋚ d,a ⋚ d) of
    (LT,LT,_) -> 
      -- we have x < a 
      --         x < d
      Link x (Link a b c) (Link d e f)
    (GT,_,LT) -> 
      -- we have a < x
      --         a < d
      Link a (ramyCleanBalanceLink x b (Link d e f))
             (ramyCleanBalanceLink x c (Link d e f))
    (_,GT,GT) -> 
      -- we have d < x
      --         d < a
      Link d (ramyCleanBalanceLink x (Link a b c) e)
             (ramyCleanBalanceLink x (Link a b c) f)
    (EQ,_,_) ->
      -- we have x = a
      -- must be that d > x
      Link x b (Link d e f)
    (_,EQ,_) ->
      -- we have x = d
      -- must be that a > x
      Link x (Link a b c) f
    (_,_,EQ) ->
      -- we have a = d
      -- must be that x > a
      -- if(x){if(a){b}{c}}{if(a){e}{f}}
      -- if(a){if(x){b}{e}}{if(x){c}{f}}
      Link a (ramyCleanBalanceLink x b e)
             (ramyCleanBalanceLink x c f)
    (_,_,_) -> error "impossible"

checkInvariant ∷ NF → 𝔹
checkInvariant (Leaf _) = True
checkInvariant (Link x (Leaf y) (Leaf z)) = True
checkInvariant (Link x (Link a b c) (Leaf y)) = x < a ⩓ checkInvariant (Link a b c)
checkInvariant (Link x (Leaf y) (Link a b c)) = x < a ⩓ checkInvariant (Link a b c)
checkInvariant (Link x (Link a b c) (Link d e f)) = 
  x < a 
  ⩓ x < d 
  ⩓ checkInvariant (Link a b c) 
  ⩓ checkInvariant (Link d e f)

joinnfL ∷ LeafData → NF → NF
joinnfL s1 (Leaf s2) = Leaf (s1 ∪ s2)
joinnfL s (Link x y z) = Link x (joinnfL s y) (joinnfL s z)

joinnf ∷ NF → NF → NF
joinnf (Leaf s1) nf2 = joinnfL s1 nf2
joinnf (Link x y z) n2 = ddBalanceLink x (joinnf y n2) (joinnf z n2)

dprodnfL ∷ LeafData → NF → NF
dprodnfL s1 (Leaf s2) = Leaf (set𝐿 (cartWith (⧺) (list𝑃 s1) (list𝑃 s2)))
dprodnfL s (Link x y z) = Link x (dprodnfL s y) (dprodnfL s z)

dprodnf ∷ NF → NF → NF
dprodnf (Leaf s1) nf2 = dprodnfL s1 nf2
dprodnf (Link x y z) n2 = ddBalanceLink x (dprodnf y n2) (dprodnf z n2)

neoBalanceLink ∷ LeafData → NF → NF → NF
neoBalanceLink x (Leaf a) (Leaf b) = 
    Link x (Leaf a) (Leaf b)
neoBalanceLink x (Leaf a) (Link b c d) = 
    case (b < x) of
      False -> Link x (Leaf a) (Link b c d)
      True -> Link b (neoBalanceLink x (Leaf a) c) (neoBalanceLink x (Leaf a) d)
neoBalanceLink x (Link a b c) (Leaf d) =
    case (a < x) of
      False -> Link x (Link a b c) (Leaf d)
      True -> Link a (neoBalanceLink x b (Leaf d)) (neoBalanceLink x c (Leaf d))      
neoBalanceLink x (Link a b c) (Link d e f) =
    case (x < a) of
      True ->
        case (x < d) of
          True -> Link x (neoBalanceLink a b c) (neoBalanceLink d e f)
          False -> Link d (Link x (neoBalanceLink a b c) e) (Link x (neoBalanceLink a b c) f)
      False ->
        case (x < d) of
          True -> Link a (neoBalanceLink x b (neoBalanceLink d e f)) (neoBalanceLink x c (neoBalanceLink d e f))
          False ->
            case (a < d) of
              True ->
                Link a (neoBalanceLink x b (neoBalanceLink d e f)) (neoBalanceLink x c (neoBalanceLink d e f))
              False ->
                Link d (neoBalanceLink x (neoBalanceLink a b c) e) (neoBalanceLink x (neoBalanceLink a b c) f)
-- joinnf n1 n2 = case n1 of
--   Leaf s1 ->
--     case n2 of
--       Leaf s2 -> --take the union of two leaves 
--         Leaf (s1 ∪ s2)
--       Link x2 y2 z2 -> --propagate the left leaf into the right link
--   Link x y z --set the left link to take precedence, and propagate right link into it


-- dprodnf ∷ NF → NF → NF
-- dprodnf n1 n2 = case n1 of
--   Leaf s1 ->
--     case n2 of
--       Leaf s2 -> --we have two leaves, so we take the cartesian product of them
--         Leaf $ set𝐿 $ cartWith (⧺) (list𝑃 s1) (list𝑃 s2)
--       -- we have a leaf and a link. The guard of the link takes precedence,
--       -- and we distribute the contents of the leaf to the rest of the Link
--       Link x2 y2 z2 -> 
--         Link x2 (joinnf y2 (Leaf s1)) (joinnf z2 (Leaf s1))
--   -- if n1 is a link, it takes precedence
--   -- TODO: have the order determined by which is less than the other
--   Link x y z
--     -> Link x (joinnf y n2) (joinnf z n2)
 
-- ifnf n1 n2 n3
-- if we assume n1,n2,n3 balanced, then this returns a balanced tree
ifnf ∷ NF → NF → NF → NF
ifnf (Leaf g) n1 n2 = ddBalanceLink g n1 n2
-- if(if(x){y}{z}){a}{b} normalizes to if(x){if(y){a}{b}}{if(z){a}{b}}
ifnf (Link x y z) a b = ddBalanceLink x (ifnf y a b) (ifnf z a b) 

-- maybe this is what you want???? -DCD
-- combineLink ∷ LeafData → NF → NF → NF → NF
-- combineLink ld tb fb nf = undefined

-- ifnf sps n1 n2 = case sps of
--   Leaf g -> ifnfutil (list𝑃 g) n1 n2 
--   Link n n1 n2 -> Link n n1 n2

-- ifnfutil ∷ 𝐿 (𝐿 𝕊) → NF → NF → NF
-- ifnfutil (l :& Nil) n1 n2 = ifnfprods l n1 n2
-- --was not sure what to do in this case; assumed that different lists within leaf should be joined
-- ifnfutil (l :& ls) n1 n2 = joinnf (ifnfprods l n1 n2) (ifnfutil ls n1 n2)
-- 
-- ifnfprods ∷ 𝐿 𝕊 → NF → NF → NF
-- ifnfprods (x :& Nil) n1 n2 = Link x n1 n2
-- ifnfprods (x :& xs) n1 n2 = dprodnf (Link x n1 n2) (ifnfprods xs n1 n2) 
-- --ifnf (Leaf (sps ∷ 𝑃 (𝐿 𝕊))) (tb ∷ NF) (fb ∷ NF) = undefined

-- a ⊔ b == if a then true else b
-- a ⋉ b == if a then b else false


-- !! complete normalize
-- it must be guaranteed that normalize will return a balanced tree
normalize 
  ∷ Exp  -- ^ The JSDP expression
  → NF   -- ^ The normalized expression.
normalize e = case e of
  Lit b -> case b of
     True ->
         Leaf $ set [list []]
     False ->
         Leaf $ set []
  Var x ->
    Leaf $ set [list [x]] 
  Join x y -> 
    joinnf (normalize x) (normalize y)
  DProd x y ->
    dprodnf (normalize x) (normalize y)
  If x y z ->
    ifnf (normalize x) (normalize y) (normalize z)
    --case x of --Only works when the guard is a Var, need to implement ifnf
      --Var v -> Link v (normalize y) (normalize z)

equiv ∷ Exp → Exp → 𝔹
equiv e1 e2 = (normalize e1) == (normalize e2) --thats it?
-- equiv e₁ e₂ = normalize e₁ ≟ normalize e₂
