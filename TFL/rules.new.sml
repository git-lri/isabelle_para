(*  Title:      TFL/rules
    ID:         $Id$
    Author:     Konrad Slind, Cambridge University Computer Laboratory
    Copyright   1997  University of Cambridge

Emulation of HOL inference rules for TFL
*)

structure Rules : Rules_sig = 
struct

open Utils;

structure USyntax  = USyntax;
structure S  = USyntax;
structure U  = Utils;
structure D = Dcterm;


fun RULES_ERR{func,mesg} = Utils.ERR{module = "Rules",func=func,mesg=mesg};


fun cconcl thm = D.drop_prop(#prop(crep_thm thm));
fun chyps thm = map D.drop_prop(#hyps(crep_thm thm));

fun dest_thm thm = 
   let val {prop,hyps,...} = rep_thm thm
   in (map HOLogic.dest_Trueprop hyps, HOLogic.dest_Trueprop prop)
   end;



(* Inference rules *)

(*---------------------------------------------------------------------------
 *        Equality (one step)
 *---------------------------------------------------------------------------*)
fun REFL tm = Thm.reflexive tm RS meta_eq_to_obj_eq;
fun SYM thm = thm RS sym;

fun ALPHA thm ctm1 =
   let val ctm2 = cprop_of thm
       val ctm2_eq = reflexive ctm2
       val ctm1_eq = reflexive ctm1
   in equal_elim (transitive ctm2_eq ctm1_eq) thm
   end;


(*----------------------------------------------------------------------------
 *        typ instantiation
 *---------------------------------------------------------------------------*)
fun INST_TYPE blist thm = 
  let val {sign,...} = rep_thm thm
      val blist' = map (fn (TVar(idx,_), B) => (idx, ctyp_of sign B)) blist
  in Thm.instantiate (blist',[]) thm
  end
  handle _ => raise RULES_ERR{func = "INST_TYPE", mesg = ""};


(*----------------------------------------------------------------------------
 *        Implication and the assumption list
 *
 * Assumptions get stuck on the meta-language assumption list. Implications 
 * are in the object language, so discharging an assumption "A" from theorem
 * "B" results in something that looks like "A --> B".
 *---------------------------------------------------------------------------*)
fun ASSUME ctm = Thm.assume (D.mk_prop ctm);


(*---------------------------------------------------------------------------
 * Implication in TFL is -->. Meta-language implication (==>) is only used
 * in the implementation of some of the inference rules below.
 *---------------------------------------------------------------------------*)
fun MP th1 th2 = th2 RS (th1 RS mp);

fun DISCH tm thm = Thm.implies_intr (D.mk_prop tm) thm COMP impI;

fun DISCH_ALL thm = Utils.itlist DISCH (#hyps (crep_thm thm)) thm;


fun FILTER_DISCH_ALL P thm =
 let fun check tm = U.holds P (#t(rep_cterm tm))
 in  foldr (fn (tm,th) => if (check tm) then DISCH tm th else th)
              (chyps thm, thm)
 end;

(* freezeT expensive! *)
fun UNDISCH thm = 
   let val tm = D.mk_prop(#1(D.dest_imp(cconcl (freezeT thm))))
   in implies_elim (thm RS mp) (ASSUME tm)
   end
   handle _ => raise RULES_ERR{func = "UNDISCH", mesg = ""};

fun PROVE_HYP ath bth =  MP (DISCH (cconcl ath) bth) ath;

local val [p1,p2] = goal HOL.thy "(A-->B) ==> (B --> C) ==> (A-->C)"
      val dummy = by (rtac impI 1)
      val dummy = by (rtac (p2 RS mp) 1)
      val dummy = by (rtac (p1 RS mp) 1)
      val dummy = by (assume_tac 1)
      val imp_trans = result()
in
fun IMP_TRANS th1 th2 = th2 RS (th1 RS imp_trans)
end;

(*----------------------------------------------------------------------------
 *        Conjunction
 *---------------------------------------------------------------------------*)
fun CONJUNCT1 thm = (thm RS conjunct1)
fun CONJUNCT2 thm = (thm RS conjunct2);
fun CONJUNCTS th  = (CONJUNCTS (CONJUNCT1 th) @ CONJUNCTS (CONJUNCT2 th))
                    handle _ => [th];

fun LIST_CONJ [] = raise RULES_ERR{func = "LIST_CONJ", mesg = "empty list"}
  | LIST_CONJ [th] = th
  | LIST_CONJ (th::rst) = MP(MP(conjI COMP (impI RS impI)) th) (LIST_CONJ rst);


(*----------------------------------------------------------------------------
 *        Disjunction
 *---------------------------------------------------------------------------*)
local val {prop,sign,...} = rep_thm disjI1
      val [P,Q] = term_vars prop
      val disj1 = forall_intr (cterm_of sign Q) disjI1
in
fun DISJ1 thm tm = thm RS (forall_elim (D.drop_prop tm) disj1)
end;

local val {prop,sign,...} = rep_thm disjI2
      val [P,Q] = term_vars prop
      val disj2 = forall_intr (cterm_of sign P) disjI2
in
fun DISJ2 tm thm = thm RS (forall_elim (D.drop_prop tm) disj2)
end;


(*----------------------------------------------------------------------------
 *
 *                   A1 |- M1, ..., An |- Mn
 *     ---------------------------------------------------
 *     [A1 |- M1 \/ ... \/ Mn, ..., An |- M1 \/ ... \/ Mn]
 *
 *---------------------------------------------------------------------------*)


fun EVEN_ORS thms =
  let fun blue ldisjs [] _ = []
        | blue ldisjs (th::rst) rdisjs =
            let val tail = tl rdisjs
                val rdisj_tl = D.list_mk_disj tail
            in itlist DISJ2 ldisjs (DISJ1 th rdisj_tl)
               :: blue (ldisjs@[cconcl th]) rst tail
            end handle _ => [itlist DISJ2 ldisjs th]
   in
   blue [] thms (map cconcl thms)
   end;


(*----------------------------------------------------------------------------
 *
 *         A |- P \/ Q   B,P |- R    C,Q |- R
 *     ---------------------------------------------------
 *                     A U B U C |- R
 *
 *---------------------------------------------------------------------------*)
local val [p1,p2,p3] = goal HOL.thy "(P | Q) ==> (P --> R) ==> (Q --> R) ==> R"
      val dummy = by (rtac (p1 RS disjE) 1)
      val dummy = by (rtac (p2 RS mp) 1)
      val dummy = by (assume_tac 1)
      val dummy = by (rtac (p3 RS mp) 1)
      val dummy = by (assume_tac 1)
      val tfl_exE = result()
in
fun DISJ_CASES th1 th2 th3 = 
   let val c = D.drop_prop(cconcl th1)
       val (disj1,disj2) = D.dest_disj c
       val th2' = DISCH disj1 th2
       val th3' = DISCH disj2 th3
   in
   th3' RS (th2' RS (th1 RS tfl_exE))
   end
end;


(*-----------------------------------------------------------------------------
 *
 *       |- A1 \/ ... \/ An     [A1 |- M, ..., An |- M]
 *     ---------------------------------------------------
 *                           |- M
 *
 * Note. The list of theorems may be all jumbled up, so we have to 
 * first organize it to align with the first argument (the disjunctive 
 * theorem).
 *---------------------------------------------------------------------------*)

fun organize eq =    (* a bit slow - analogous to insertion sort *)
 let fun extract a alist =
     let fun ex (_,[]) = raise RULES_ERR{func = "organize",
                                         mesg = "not a permutation.1"}
           | ex(left,h::t) = if (eq h a) then (h,rev left@t) else ex(h::left,t)
     in ex ([],alist)
     end
     fun place [] [] = []
       | place (a::rst) alist =
           let val (item,next) = extract a alist
           in item::place rst next
           end
       | place _ _ = raise RULES_ERR{func = "organize",
                                     mesg = "not a permutation.2"}
 in place
 end;
(* freezeT expensive! *)
fun DISJ_CASESL disjth thl =
   let val c = cconcl disjth
       fun eq th atm = exists (fn t => HOLogic.dest_Trueprop t 
			               aconv term_of atm)
	                      (#hyps(rep_thm th))
       val tml = D.strip_disj c
       fun DL th [] = raise RULES_ERR{func="DISJ_CASESL",mesg="no cases"}
         | DL th [th1] = PROVE_HYP th th1
         | DL th [th1,th2] = DISJ_CASES th th1 th2
         | DL th (th1::rst) = 
            let val tm = #2(D.dest_disj(D.drop_prop(cconcl th)))
             in DISJ_CASES th th1 (DL (ASSUME tm) rst) end
   in DL (freezeT disjth) (organize eq tml thl)
   end;


(*----------------------------------------------------------------------------
 *        Universals
 *---------------------------------------------------------------------------*)
local (* this is fragile *)
      val {prop,sign,...} = rep_thm spec
      val x = hd (tl (term_vars prop))
      val (TVar (indx,_)) = type_of x
      val gspec = forall_intr (cterm_of sign x) spec
in
fun SPEC tm thm = 
   let val {sign,T,...} = rep_cterm tm
       val gspec' = instantiate([(indx,ctyp_of sign T)],[]) gspec
   in thm RS (forall_elim tm gspec')
   end
end;

fun SPEC_ALL thm = rev_itlist SPEC (#1(D.strip_forall(cconcl thm))) thm;

val ISPEC = SPEC
val ISPECL = rev_itlist ISPEC;

(* Not optimized! Too complicated. *)
local val {prop,sign,...} = rep_thm allI
      val [P] = add_term_vars (prop, [])
      fun cty_theta s = map (fn (i,ty) => (i, ctyp_of s ty))
      fun ctm_theta s = map (fn (i,tm2) => 
                             let val ctm2 = cterm_of s tm2
                             in (cterm_of s (Var(i,#T(rep_cterm ctm2))), ctm2)
                             end)
      fun certify s (ty_theta,tm_theta) = (cty_theta s ty_theta, 
                                           ctm_theta s tm_theta)
in
fun GEN v th =
   let val gth = forall_intr v th
       val {prop=Const("all",_)$Abs(x,ty,rst),sign,...} = rep_thm gth
       val P' = Abs(x,ty, HOLogic.dest_Trueprop rst)  (* get rid of trueprop *)
       val tsig = #tsig(Sign.rep_sg sign)
       val theta = Pattern.match tsig (P,P')
       val allI2 = instantiate (certify sign theta) allI
       val thm = implies_elim allI2 gth
       val {prop = tp $ (A $ Abs(_,_,M)),sign,...} = rep_thm thm
       val prop' = tp $ (A $ Abs(x,ty,M))
   in ALPHA thm (cterm_of sign prop')
   end
end;

val GENL = itlist GEN;

fun GEN_ALL thm = 
   let val {prop,sign,...} = rep_thm thm
       val tycheck = cterm_of sign
       val vlist = map tycheck (add_term_vars (prop, []))
  in GENL vlist thm
  end;


fun MATCH_MP th1 th2 = 
   if (D.is_forall (D.drop_prop(cconcl th1)))
   then MATCH_MP (th1 RS spec) th2
   else MP th1 th2;


(*----------------------------------------------------------------------------
 *        Existentials
 *---------------------------------------------------------------------------*)



(*--------------------------------------------------------------------------- 
 * Existential elimination
 *
 *      A1 |- ?x.t[x]   ,   A2, "t[v]" |- t'
 *      ------------------------------------     (variable v occurs nowhere)
 *                A1 u A2 |- t'
 *
 *---------------------------------------------------------------------------*)

local val [p1,p2] = goal HOL.thy "(? x. P x) ==> (!x. P x --> Q) ==> Q"
      val dummy = by (rtac (p1 RS exE) 1)
      val dummy = by (rtac ((p2 RS allE) RS mp) 1)
      val dummy = by (assume_tac 2)
      val dummy = by (assume_tac 1)
      val choose_thm = result()
in
fun CHOOSE(fvar,exth) fact =
   let val lam = #2(dest_comb(D.drop_prop(cconcl exth)))
       val redex = capply lam fvar
       val {sign, t = t$u,...} = rep_cterm redex
       val residue = cterm_of sign (betapply(t,u))
    in GEN fvar (DISCH residue fact)  RS (exth RS choose_thm)
   end
end;


local val {prop,sign,...} = rep_thm exI
      val [P,x] = term_vars prop
in
fun EXISTS (template,witness) thm =
   let val {prop,sign,...} = rep_thm thm
       val P' = cterm_of sign P
       val x' = cterm_of sign x
       val abstr = #2(dest_comb template)
   in
   thm RS (cterm_instantiate[(P',abstr), (x',witness)] exI)
   end
end;

(*----------------------------------------------------------------------------
 *
 *         A |- M
 *   -------------------   [v_1,...,v_n]
 *    A |- ?v1...v_n. M
 *
 *---------------------------------------------------------------------------*)

fun EXISTL vlist th = 
  U.itlist (fn v => fn thm => EXISTS(D.mk_exists(v,cconcl thm), v) thm)
           vlist th;


(*----------------------------------------------------------------------------
 *
 *       A |- M[x_1,...,x_n]
 *   ----------------------------   [(x |-> y)_1,...,(x |-> y)_n]
 *       A |- ?y_1...y_n. M
 *
 *---------------------------------------------------------------------------*)
(* Could be improved, but needs "subst_free" for certified terms *)

fun IT_EXISTS blist th = 
   let val {sign,...} = rep_thm th
       val tych = cterm_of sign
       val detype = #t o rep_cterm
       val blist' = map (fn (x,y) => (detype x, detype y)) blist
       fun ?v M  = cterm_of sign (S.mk_exists{Bvar=v,Body = M})
       
  in
  U.itlist (fn (b as (r1,r2)) => fn thm => 
        EXISTS(?r2(subst_free[b] 
		   (HOLogic.dest_Trueprop(#prop(rep_thm thm)))), tych r1)
              thm)
       blist' th
  end;

(*---------------------------------------------------------------------------
 *  Faster version, that fails for some as yet unknown reason
 * fun IT_EXISTS blist th = 
 *    let val {sign,...} = rep_thm th
 *        val tych = cterm_of sign
 *        fun detype (x,y) = ((#t o rep_cterm) x, (#t o rep_cterm) y)
 *   in
 *  fold (fn (b as (r1,r2), thm) => 
 *  EXISTS(D.mk_exists(r2, tych(subst_free[detype b](#t(rep_cterm(cconcl thm))))),
 *           r1) thm)  blist th
 *   end;
 *---------------------------------------------------------------------------*)

(*----------------------------------------------------------------------------
 *        Rewriting
 *---------------------------------------------------------------------------*)

fun SUBS thl = 
   rewrite_rule (map (fn th => (th RS eq_reflection) handle _ => th) thl);

local fun rew_conv mss = rewrite_cterm (true,false) mss (K(K None))
in
fun simpl_conv ss thl ctm = 
 rew_conv (Thm.mss_of (#simps (Thm.dest_mss (#mss (rep_ss ss))) @ thl)) ctm
 RS meta_eq_to_obj_eq
end;

local fun prover s = prove_goal HOL.thy s (fn _ => [fast_tac HOL_cs 1])
in
val RIGHT_ASSOC = rewrite_rule [prover"((a|b)|c) = (a|(b|c))" RS eq_reflection]
val ASM = refl RS iffD1
end;




(*---------------------------------------------------------------------------
 *                  TERMINATION CONDITION EXTRACTION
 *---------------------------------------------------------------------------*)


(* Object language quantifier, i.e., "!" *)
fun Forall v M = S.mk_forall{Bvar=v, Body=M};


(* Fragile: it's a cong if it is not "R y x ==> cut f R x y = f y" *)
fun is_cong thm = 
  let val {prop, ...} = rep_thm thm
  in case prop 
     of (Const("==>",_)$(Const("Trueprop",_)$ _) $
         (Const("==",_) $ (Const ("cut",_) $ f $ R $ a $ x) $ _)) => false
      | _ => true
  end;


   
fun dest_equal(Const ("==",_) $ 
	       (Const ("Trueprop",_) $ lhs) 
	       $ (Const ("Trueprop",_) $ rhs)) = {lhs=lhs, rhs=rhs}
  | dest_equal(Const ("==",_) $ lhs $ rhs)  = {lhs=lhs, rhs=rhs}
  | dest_equal tm = S.dest_eq tm;

fun get_lhs tm = #lhs(dest_equal (HOLogic.dest_Trueprop tm));

fun dest_all(Const("all",_) $ (a as Abs _)) = S.dest_abs a
  | dest_all _ = raise RULES_ERR{func = "dest_all", mesg = "not a !!"};

val is_all = Utils.can dest_all;

fun strip_all fm =
   if (is_all fm)
   then let val {Bvar,Body} = dest_all fm
            val (bvs,core)  = strip_all Body
        in ((Bvar::bvs), core)
        end
   else ([],fm);

fun break_all(Const("all",_) $ Abs (_,_,body)) = body
  | break_all _ = raise RULES_ERR{func = "break_all", mesg = "not a !!"};

fun list_break_all(Const("all",_) $ Abs (s,ty,body)) = 
     let val (L,core) = list_break_all body
     in ((s,ty)::L, core)
     end
  | list_break_all tm = ([],tm);

(*---------------------------------------------------------------------------
 * Rename a term of the form
 *
 *      !!x1 ...xn. x1=M1 ==> ... ==> xn=Mn 
 *                  ==> ((%v1...vn. Q) x1 ... xn = g x1 ... xn.
 * to one of
 *
 *      !!v1 ... vn. v1=M1 ==> ... ==> vn=Mn 
 *      ==> ((%v1...vn. Q) v1 ... vn = g v1 ... vn.
 * 
 * This prevents name problems in extraction, and helps the result to read
 * better. There is a problem with varstructs, since they can introduce more
 * than n variables, and some extra reasoning needs to be done.
 *---------------------------------------------------------------------------*)

fun get ([],_,L) = rev L
  | get (ant::rst,n,L) =  
      case (list_break_all ant)
        of ([],_) => get (rst, n+1,L)
         | (vlist,body) =>
            let val eq = Logic.strip_imp_concl body
                val (f,args) = S.strip_comb (get_lhs eq)
                val (vstrl,_) = S.strip_abs f
                val names  = variantlist (map (#1 o dest_Free) vstrl,
					  add_term_names(body, []))
            in get (rst, n+1, (names,n)::L)
            end handle _ => get (rst, n+1, L);

(* Note: rename_params_rule counts from 1, not 0 *)
fun rename thm = 
  let val {prop,sign,...} = rep_thm thm
      val tych = cterm_of sign
      val ants = Logic.strip_imp_prems prop
      val news = get (ants,1,[])
  in 
  U.rev_itlist rename_params_rule news thm
  end;


(*---------------------------------------------------------------------------
 * Beta-conversion to the rhs of an equation (taken from hol90/drule.sml)
 *---------------------------------------------------------------------------*)

fun list_beta_conv tm =
  let fun rbeta th = transitive th (beta_conversion(#2(D.dest_eq(cconcl th))))
      fun iter [] = reflexive tm
        | iter (v::rst) = rbeta (combination(iter rst) (reflexive v))
  in iter  end;


(*---------------------------------------------------------------------------
 * Trace information for the rewriter
 *---------------------------------------------------------------------------*)
val term_ref = ref[] : term list ref
val mss_ref = ref [] : meta_simpset list ref;
val thm_ref = ref [] : thm list ref;
val tracing = ref false;

fun say s = if !tracing then prs s else ();

fun print_thms s L = 
   (say s; 
    map (fn th => say (string_of_thm th ^"\n")) L;
    say"\n");

fun print_cterms s L = 
   (say s; 
    map (fn th => say (string_of_cterm th ^"\n")) L;
    say"\n");

(*---------------------------------------------------------------------------
 * General abstraction handlers, should probably go in USyntax.
 *---------------------------------------------------------------------------*)
fun mk_aabs(vstr,body) = S.mk_abs{Bvar=vstr,Body=body}
                         handle _ => S.mk_pabs{varstruct = vstr, body = body};

fun list_mk_aabs (vstrl,tm) =
    U.itlist (fn vstr => fn tm => mk_aabs(vstr,tm)) vstrl tm;

fun dest_aabs tm = 
   let val {Bvar,Body} = S.dest_abs tm
   in (Bvar,Body)
   end handle _ => let val {varstruct,body} = S.dest_pabs tm
                   in (varstruct,body)
                   end;

fun strip_aabs tm =
   let val (vstr,body) = dest_aabs tm
       val (bvs, core) = strip_aabs body
   in (vstr::bvs, core)
   end
   handle _ => ([],tm);

fun dest_combn tm 0 = (tm,[])
  | dest_combn tm n = 
     let val {Rator,Rand} = S.dest_comb tm
         val (f,rands) = dest_combn Rator (n-1)
     in (f,Rand::rands)
     end;




local fun dest_pair M = let val {fst,snd} = S.dest_pair M in (fst,snd) end
      fun mk_fst tm = 
          let val ty as Type("*", [fty,sty]) = type_of tm
          in  Const ("fst", ty --> fty) $ tm  end
      fun mk_snd tm = 
          let val ty as Type("*", [fty,sty]) = type_of tm
          in  Const ("snd", ty --> sty) $ tm  end
in
fun XFILL tych x vstruct = 
  let fun traverse p xocc L =
        if (is_Free p)
        then tych xocc::L
        else let val (p1,p2) = dest_pair p
             in traverse p1 (mk_fst xocc) (traverse p2  (mk_snd xocc) L)
             end
  in 
  traverse vstruct x []
end end;

(*---------------------------------------------------------------------------
 * Replace a free tuple (vstr) by a universally quantified variable (a).
 * Note that the notion of "freeness" for a tuple is different than for a
 * variable: if variables in the tuple also occur in any other place than
 * an occurrences of the tuple, they aren't "free" (which is thus probably
 *  the wrong word to use).
 *---------------------------------------------------------------------------*)

fun VSTRUCT_ELIM tych a vstr th = 
  let val L = S.free_vars_lr vstr
      val bind1 = tych (HOLogic.mk_Trueprop (HOLogic.mk_eq(a,vstr)))
      val thm1 = implies_intr bind1 (SUBS [SYM(assume bind1)] th)
      val thm2 = forall_intr_list (map tych L) thm1
      val thm3 = forall_elim_list (XFILL tych a vstr) thm2
  in refl RS
     rewrite_rule[symmetric (surjective_pairing RS eq_reflection)] thm3
  end;

fun PGEN tych a vstr th = 
  let val a1 = tych a
      val vstr1 = tych vstr
  in
  forall_intr a1 
     (if (is_Free vstr) 
      then cterm_instantiate [(vstr1,a1)] th
      else VSTRUCT_ELIM tych a vstr th)
  end;


(*---------------------------------------------------------------------------
 * Takes apart a paired beta-redex, looking like "(\(x,y).N) vstr", into
 *
 *     (([x,y],N),vstr)
 *---------------------------------------------------------------------------*)
fun dest_pbeta_redex M n = 
  let val (f,args) = dest_combn M n
      val dummy = dest_aabs f
  in (strip_aabs f,args)
  end;

fun pbeta_redex M n = U.can (U.C dest_pbeta_redex n) M;

fun dest_impl tm = 
  let val ants = Logic.strip_imp_prems tm
      val eq = Logic.strip_imp_concl tm
  in (ants,get_lhs eq)
  end;

fun restricted t = is_some (S.find_term
			    (fn (Const("cut",_)) =>true | _ => false) 
			    t)

fun CONTEXT_REWRITE_RULE (ss, func, R, cut_lemma, congs) th =
 let val pbeta_reduce = simpl_conv ss [split RS eq_reflection];
     val tc_list = ref[]: term list ref
     val dummy = term_ref := []
     val dummy = thm_ref  := []
     val dummy = mss_ref  := []
     val cut_lemma' = (cut_lemma RS mp) RS eq_reflection
     fun prover mss thm =
     let fun cong_prover mss thm =
         let val dummy = say "cong_prover:\n"
             val cntxt = prems_of_mss mss
             val dummy = print_thms "cntxt:\n" cntxt
             val dummy = say "cong rule:\n"
             val dummy = say (string_of_thm thm^"\n")
             val dummy = thm_ref := (thm :: !thm_ref)
             val dummy = mss_ref := (mss :: !mss_ref)
             (* Unquantified eliminate *)
             fun uq_eliminate (thm,imp,sign) = 
                 let val tych = cterm_of sign
                     val dummy = print_cterms "To eliminate:\n" [tych imp]
                     val ants = map tych (Logic.strip_imp_prems imp)
                     val eq = Logic.strip_imp_concl imp
                     val lhs = tych(get_lhs eq)
                     val mss' = add_prems(mss, map ASSUME ants)
                     val lhs_eq_lhs1 = rewrite_cterm(false,true)mss' prover lhs
                       handle _ => reflexive lhs
                     val dummy = print_thms "proven:\n" [lhs_eq_lhs1]
                     val lhs_eq_lhs2 = implies_intr_list ants lhs_eq_lhs1
                     val lhs_eeq_lhs2 = lhs_eq_lhs2 RS meta_eq_to_obj_eq
                  in
                  lhs_eeq_lhs2 COMP thm
                  end
             fun pq_eliminate (thm,sign,vlist,imp_body,lhs_eq) =
              let val ((vstrl,_),args) = dest_pbeta_redex lhs_eq(length vlist)
                  val dummy = assert (forall (op aconv)
                                      (ListPair.zip (vlist, args)))
                               "assertion failed in CONTEXT_REWRITE_RULE"
                  val imp_body1 = subst_free (ListPair.zip (args, vstrl))
                                             imp_body
                  val tych = cterm_of sign
                  val ants1 = map tych (Logic.strip_imp_prems imp_body1)
                  val eq1 = Logic.strip_imp_concl imp_body1
                  val Q = get_lhs eq1
                  val QeqQ1 = pbeta_reduce (tych Q)
                  val Q1 = #2(D.dest_eq(cconcl QeqQ1))
                  val mss' = add_prems(mss, map ASSUME ants1)
                  val Q1eeqQ2 = rewrite_cterm (false,true) mss' prover Q1
                                handle _ => reflexive Q1
                  val Q2 = #2 (Logic.dest_equals (#prop(rep_thm Q1eeqQ2)))
                  val Q3 = tych(list_comb(list_mk_aabs(vstrl,Q2),vstrl))
                  val Q2eeqQ3 = symmetric(pbeta_reduce Q3 RS eq_reflection)
                  val thA = transitive(QeqQ1 RS eq_reflection) Q1eeqQ2
                  val QeeqQ3 = transitive thA Q2eeqQ3 handle _ =>
                               ((Q2eeqQ3 RS meta_eq_to_obj_eq) 
                                RS ((thA RS meta_eq_to_obj_eq) RS trans))
                                RS eq_reflection
                  val impth = implies_intr_list ants1 QeeqQ3
                  val impth1 = impth RS meta_eq_to_obj_eq
                  (* Need to abstract *)
                  val ant_th = U.itlist2 (PGEN tych) args vstrl impth1
              in ant_th COMP thm
              end
             fun q_eliminate (thm,imp,sign) =
              let val (vlist,imp_body) = strip_all imp
                  val (ants,Q) = dest_impl imp_body
              in if (pbeta_redex Q) (length vlist)
                 then pq_eliminate (thm,sign,vlist,imp_body,Q)
                 else 
                 let val tych = cterm_of sign
                     val ants1 = map tych ants
                     val mss' = add_prems(mss, map ASSUME ants1)
                     val Q_eeq_Q1 = rewrite_cterm(false,true) mss' 
                                                     prover (tych Q)
                      handle _ => reflexive (tych Q)
                     val lhs_eeq_lhs2 = implies_intr_list ants1 Q_eeq_Q1
                     val lhs_eq_lhs2 = lhs_eeq_lhs2 RS meta_eq_to_obj_eq
                     val ant_th = forall_intr_list(map tych vlist)lhs_eq_lhs2
                 in
                 ant_th COMP thm
              end end

             fun eliminate thm = 
               case (rep_thm thm)
               of {prop = (Const("==>",_) $ imp $ _), sign, ...} =>
                   eliminate
                    (if not(is_all imp)
                     then uq_eliminate (thm,imp,sign)
                     else q_eliminate (thm,imp,sign))
                            (* Assume that the leading constant is ==,   *)
                | _ => thm  (* if it is not a ==>                        *)
         in Some(eliminate (rename thm))
         end handle _ => None

        fun restrict_prover mss thm =
          let val dummy = say "restrict_prover:\n"
              val cntxt = rev(prems_of_mss mss)
              val dummy = print_thms "cntxt:\n" cntxt
              val {prop = Const("==>",_) $ (Const("Trueprop",_) $ A) $ _,
                   sign,...} = rep_thm thm
              fun genl tm = let val vlist = gen_rems (op aconv)
                                           (add_term_frees(tm,[]), [func,R])
                            in U.itlist Forall vlist tm
                            end
              (*--------------------------------------------------------------
               * This actually isn't quite right, since it will think that
               * not-fully applied occs. of "f" in the context mean that the
               * current call is nested. The real solution is to pass in a
               * term "f v1..vn" which is a pattern that any full application
               * of "f" will match.
               *-------------------------------------------------------------*)
              val func_name = #1(dest_Const func)
              fun is_func (Const (name,_)) = (name = func_name)
		| is_func _                = false
              val rcontext = rev cntxt
              val cncl = HOLogic.dest_Trueprop o #prop o rep_thm
              val antl = case rcontext of [] => [] 
                         | _   => [S.list_mk_conj(map cncl rcontext)]
              val TC = genl(S.list_mk_imp(antl, A))
              val dummy = print_cterms "func:\n" [cterm_of sign func]
              val dummy = print_cterms "TC:\n" 
		              [cterm_of sign (HOLogic.mk_Trueprop TC)]
              val dummy = tc_list := (TC :: !tc_list)
              val nestedp = is_some (S.find_term is_func TC)
              val dummy = if nestedp then say"nested\n" else say"not_nested\n"
              val dummy = term_ref := ([func,TC]@(!term_ref))
              val th' = if nestedp then raise RULES_ERR{func = "solver", 
                                                      mesg = "nested function"}
                        else let val cTC = cterm_of sign 
			                      (HOLogic.mk_Trueprop TC)
                             in case rcontext of
                                [] => SPEC_ALL(ASSUME cTC)
                               | _ => MP (SPEC_ALL (ASSUME cTC)) 
                                         (LIST_CONJ rcontext)
                             end
              val th'' = th' RS thm
          in Some (th'')
          end handle _ => None
    in
    (if (is_cong thm) then cong_prover else restrict_prover) mss thm
    end
    val ctm = cprop_of th
    val th1 = rewrite_cterm(false,true) (add_congs(mss_of [cut_lemma'], congs))
                            prover ctm
    val th2 = equal_elim th1 th
 in
 (th2, filter (not o restricted) (!tc_list))
 end;



fun prove (ptm,tac) = 
    #1 (freeze_thaw (prove_goalw_cterm [] ptm (fn _ => [tac])));


end; (* Rules *)
