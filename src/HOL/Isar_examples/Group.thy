(*  Title:      HOL/Isar_examples/Group.thy
    ID:         $Id$
    Author:     Markus Wenzel, TU Muenchen
*)

header {* Basic group theory *};

theory Group = Main:;

subsection {* Groups *}; 

text {*
 We define an axiomatic type class of general groups over signature
 $({\times} :: \alpha \To \alpha \To \alpha, \idt{one} :: \alpha,
 \idt{inv} :: \alpha \To \alpha)$.
*};

consts
  one :: "'a"
  inv :: "'a => 'a";

axclass
  group < times
  group_assoc:         "(x * y) * z = x * (y * z)"
  group_left_unit:     "one * x = x"
  group_left_inverse:  "inv x * x = one";

text {*
 The group axioms only state the properties of left unit and inverse,
 the right versions are derivable as follows.  The calculational proof
 style below closely follows typical presentations given in any basic
 course on algebra.
*};

theorem group_right_inverse: "x * inv x = (one::'a::group)";
proof -;
  have "x * inv x = one * (x * inv x)";
    by (simp only: group_left_unit);
  also; have "... = (one * x) * inv x";
    by (simp only: group_assoc);
  also; have "... = inv (inv x) * inv x * x * inv x";
    by (simp only: group_left_inverse);
  also; have "... = inv (inv x) * (inv x * x) * inv x";
    by (simp only: group_assoc);
  also; have "... = inv (inv x) * one * inv x";
    by (simp only: group_left_inverse);
  also; have "... = inv (inv x) * (one * inv x)";
    by (simp only: group_assoc);
  also; have "... = inv (inv x) * inv x";
    by (simp only: group_left_unit);
  also; have "... = one";
    by (simp only: group_left_inverse);
  finally; show ?thesis; .;
qed;

text {*
 With \name{group-right-inverse} already at our disposal,
 \name{group-right-unit} is now obtained much easier as follows.
*};

theorem group_right_unit: "x * one = (x::'a::group)";
proof -;
  have "x * one = x * (inv x * x)";
    by (simp only: group_left_inverse);
  also; have "... = x * inv x * x";
    by (simp only: group_assoc);
  also; have "... = one * x";
    by (simp only: group_right_inverse);
  also; have "... = x";
    by (simp only: group_left_unit);
  finally; show ?thesis; .;
qed;

text {*
 \bigskip There are only two Isar language elements for calculational
 proofs: \isakeyword{also} for initial or intermediate calculational
 steps, and \isakeyword{finally} for building the result of a
 calculation.  These constructs are not hardwired into Isabelle/Isar,
 but defined on top of the basic Isar/VM interpreter.  Expanding the
 \isakeyword{also} and \isakeyword{finally} derived language elements,
 calculations may be simulated as demonstrated below.

 Note that ``$\dots$'' is just a special term binding that happens to
 be bound automatically to the argument of the last fact established
 by assume or any local goal.  In contrast to $\var{thesis}$, the
 ``$\dots$'' variable is bound \emph{after} the proof is finished.
*};

theorem "x * one = (x::'a::group)";
proof -;
  have "x * one = x * (inv x * x)";
    by (simp only: group_left_inverse);

  note calculation = this
    -- {* first calculational step: init calculation register *};

  have "... = x * inv x * x";
    by (simp only: group_assoc);

  note calculation = trans [OF calculation this]
    -- {* general calculational step: compose with transitivity rule *};

  have "... = one * x";
    by (simp only: group_right_inverse);

  note calculation = trans [OF calculation this]
    -- {* general calculational step: compose with transitivity rule *};

  have "... = x";
    by (simp only: group_left_unit);

  note calculation = trans [OF calculation this]
    -- {* final calculational step: compose with transitivity rule ... *};
  from calculation
    -- {* ... and pick up final result *};

  show ?thesis; .;
qed;


subsection {* Groups as monoids *};

text {*
  Monoids are usually defined like this.
*};

axclass monoid < times
  monoid_assoc:       "(x * y) * z = x * (y * z)"
  monoid_left_unit:   "one * x = x"
  monoid_right_unit:  "x * one = x";

text {*
 Groups are \emph{not} yet monoids directly from the definition.  For
 monoids, \name{right-unit} had to be included as an axiom, but for
 groups both \name{right-unit} and \name{right-inverse} are
 derivable from the other axioms.  With \name{group-right-unit}
 derived as a theorem of group theory (see above), we may still
 instantiate $\idt{group} \subset \idt{monoid}$ properly as follows.
*};

instance group < monoid;
  by (intro_classes,
       rule group_assoc,
       rule group_left_unit,
       rule group_right_unit);

end;
