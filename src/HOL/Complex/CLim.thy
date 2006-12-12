(*  Title       : CLim.thy
    Author      : Jacques D. Fleuriot
    Copyright   : 2001 University of Edinburgh
    Conversion to Isar and new proofs by Lawrence C Paulson, 2004
*)

header{*Limits, Continuity and Differentiation for Complex Functions*}

theory CLim
imports CSeries
begin

(*not in simpset?*)
declare hypreal_epsilon_not_zero [simp]

(*??generalize*)
lemma lemma_complex_mult_inverse_squared [simp]:
     "x \<noteq> (0::complex) \<Longrightarrow> (x * inverse(x) ^ 2) = inverse x"
by (simp add: numeral_2_eq_2)

text{*Changing the quantified variable. Install earlier?*}
lemma all_shift: "(\<forall>x::'a::comm_ring_1. P x) = (\<forall>x. P (x-a))";
apply auto 
apply (drule_tac x="x+a" in spec) 
apply (simp add: diff_minus add_assoc) 
done

lemma complex_add_minus_iff [simp]: "(x + - a = (0::complex)) = (x=a)"
by (simp add: diff_eq_eq diff_minus [symmetric])

lemma complex_add_eq_0_iff [iff]: "(x+y = (0::complex)) = (y = -x)"
apply auto
apply (drule sym [THEN diff_eq_eq [THEN iffD2]], auto)
done


subsection{*Limit of Complex to Complex Function*}

lemma NSLIM_Re: "f -- a --NS> L ==> (%x. Re(f x)) -- a --NS> Re(L)"
by (simp add: NSLIM_def starfunC_approx_Re_Im_iff 
              hRe_hcomplex_of_complex)

lemma NSLIM_Im: "f -- a --NS> L ==> (%x. Im(f x)) -- a --NS> Im(L)"
by (simp add: NSLIM_def starfunC_approx_Re_Im_iff 
              hIm_hcomplex_of_complex)

(** get this result easily now **)
lemma LIM_Re: "f -- a --> L ==> (%x. Re(f x)) -- a --> Re(L)"
by (simp add: LIM_NSLIM_iff NSLIM_Re)

lemma LIM_Im: "f -- a --> L ==> (%x. Im(f x)) -- a --> Im(L)"
by (simp add: LIM_NSLIM_iff NSLIM_Im)

lemma LIM_cnj: "f -- a --> L ==> (%x. cnj (f x)) -- a --> cnj L"
by (simp add: LIM_def complex_cnj_diff [symmetric])

lemma LIM_cnj_iff: "((%x. cnj (f x)) -- a --> cnj L) = (f -- a --> L)"
by (simp add: LIM_def complex_cnj_diff [symmetric])

(*** NSLIM_not zero and hence LIM_not_zero ***)

lemma NSCLIM_not_zero: "k \<noteq> 0 ==> ~ ((%x::complex. k) -- x --NS> 0)"
apply (auto simp del: star_of_zero simp add: NSLIM_def)
apply (rule_tac x = "hcomplex_of_complex x + hcomplex_of_hypreal epsilon" in exI)
apply (auto intro: Infinitesimal_add_approx_self [THEN approx_sym]
            simp del: star_of_zero)
done

(* [| k \<noteq> 0; (%x. k) -- x --NS> 0 |] ==> R *)
lemmas NSCLIM_not_zeroE = NSCLIM_not_zero [THEN notE, standard]

(*** NSLIM_const hence LIM_const ***)

lemma NSCLIM_const_eq: "(%x::complex. k) -- x --NS> L ==> k = L"
apply (rule ccontr)
apply (drule NSLIM_zero)
apply (rule NSCLIM_not_zeroE [of "k-L"], auto)
done

(*** NSLIM and hence LIM are unique ***)

lemma NSCLIM_unique: "[| f -- (x::complex) --NS> L; f -- x --NS> M |] ==> L = M"
apply (drule (1) NSLIM_diff)
apply (drule NSLIM_minus)
apply (auto dest!: NSCLIM_const_eq [symmetric])
done

(** another equivalence result **)
lemma NSCLIM_NSCRLIM_iff:
   "(f -- x --NS> L) = ((%y. cmod(f y - L)) -- x --NS> 0)"
apply (auto simp add: NSLIM_def Infinitesimal_approx_minus [symmetric] Infinitesimal_hcmod_iff)
apply (auto dest!: spec) 
apply (rule_tac [!] x = xa in star_cases)
apply (auto simp add: star_n_diff starfun hcmod mem_infmal_iff star_of_def)
done

(** much, much easier standard proof **)
lemma CLIM_CRLIM_iff: "(f -- x --> L) = ((%y. cmod(f y - L)) -- x --> 0)"
by (simp add: LIM_def)

(* so this is nicer nonstandard proof *)
lemma NSCLIM_NSCRLIM_iff2:
     "(f -- x --NS> L) = ((%y. cmod(f y - L)) -- x --NS> 0)"
by (simp add: LIM_NSLIM_iff [symmetric] CLIM_CRLIM_iff)

lemma NSLIM_NSCRLIM_Re_Im_iff:
     "(f -- a --NS> L) = ((%x. Re(f x)) -- a --NS> Re(L) &
                            (%x. Im(f x)) -- a --NS> Im(L))"
apply (auto intro: NSLIM_Re NSLIM_Im)
apply (auto simp add: NSLIM_def)
apply (auto dest!: spec) 
apply (rule_tac x = x in star_cases)
apply (simp add: approx_approx_iff starfun star_of_def)
done

lemma LIM_CRLIM_Re_Im_iff:
     "(f -- a --> L) = ((%x. Re(f x)) -- a --> Re(L) &
                         (%x. Im(f x)) -- a --> Im(L))"
by (simp add: LIM_NSLIM_iff NSLIM_NSCRLIM_Re_Im_iff)


subsection{*Continuity*}

lemma NSLIM_isContc_iff:
     "(f -- a --NS> f a) = ((%h. f(a + h)) -- 0 --NS> f a)"
by (rule NSLIM_h_iff)

subsection{*Functions from Complex to Reals*}

lemma isNSContCR_cmod [simp]: "isNSCont cmod (a)"
by (auto intro: approx_hcmod_approx 
         simp add: starfunCR_cmod hcmod_hcomplex_of_complex [symmetric] 
                    isNSCont_def)

lemma isContCR_cmod [simp]: "isCont cmod (a)"
by (simp add: isNSCont_isCont_iff [symmetric])

lemma isCont_Re: "isCont f a ==> isCont (%x. Re (f x)) a"
by (simp add: isCont_def LIM_Re)

lemma isCont_Im: "isCont f a ==> isCont (%x. Im (f x)) a"
by (simp add: isCont_def LIM_Im)

subsection{* Differentiation of Natural Number Powers*}

lemma CDERIV_pow [simp]:
     "DERIV (%x. x ^ n) x :> (complex_of_real (real n)) * (x ^ (n - Suc 0))"
apply (induct_tac "n")
apply (drule_tac [2] DERIV_Id [THEN DERIV_mult])
apply (auto simp add: left_distrib real_of_nat_Suc)
apply (case_tac "n")
apply (auto simp add: mult_ac add_commute)
done

text{*Nonstandard version*}
lemma NSCDERIV_pow:
     "NSDERIV (%x. x ^ n) x :> complex_of_real (real n) * (x ^ (n - 1))"
by (simp add: NSDERIV_DERIV_iff)

text{*Can't relax the premise @{term "x \<noteq> 0"}: it isn't continuous at zero*}
lemma NSCDERIV_inverse:
     "(x::complex) \<noteq> 0 ==> NSDERIV (%x. inverse(x)) x :> (- (inverse x ^ 2))"
unfolding numeral_2_eq_2
by (rule NSDERIV_inverse)

lemma CDERIV_inverse:
     "(x::complex) \<noteq> 0 ==> DERIV (%x. inverse(x)) x :> (-(inverse x ^ 2))"
unfolding numeral_2_eq_2
by (rule DERIV_inverse)


subsection{*Derivative of Reciprocals (Function @{term inverse})*}

lemma CDERIV_inverse_fun:
     "[| DERIV f x :> d; f(x) \<noteq> (0::complex) |]
      ==> DERIV (%x. inverse(f x)) x :> (- (d * inverse(f(x) ^ 2)))"
unfolding numeral_2_eq_2
by (rule DERIV_inverse_fun)

lemma NSCDERIV_inverse_fun:
     "[| NSDERIV f x :> d; f(x) \<noteq> (0::complex) |]
      ==> NSDERIV (%x. inverse(f x)) x :> (- (d * inverse(f(x) ^ 2)))"
unfolding numeral_2_eq_2
by (rule NSDERIV_inverse_fun)


subsection{* Derivative of Quotient*}

lemma CDERIV_quotient:
     "[| DERIV f x :> d; DERIV g x :> e; g(x) \<noteq> (0::complex) |]
       ==> DERIV (%y. f(y) / (g y)) x :> (d*g(x) - (e*f(x))) / (g(x) ^ 2)"
unfolding numeral_2_eq_2
by (rule DERIV_quotient)

lemma NSCDERIV_quotient:
     "[| NSDERIV f x :> d; NSDERIV g x :> e; g(x) \<noteq> (0::complex) |]
       ==> NSDERIV (%y. f(y) / (g y)) x :> (d*g(x) - (e*f(x))) / (g(x) ^ 2)"
unfolding numeral_2_eq_2
by (rule NSDERIV_quotient)


subsection{*Caratheodory Formulation of Derivative at a Point: Standard Proof*}

lemma CARAT_CDERIVD:
     "(\<forall>z. f z - f x = g z * (z - x)) & isNSCont g x & g x = l
      ==> NSDERIV f x :> l"
by clarify (rule CARAT_DERIVD)

end
