(*  Title:      HOL/MicroJava/J/JBasis.thy
    ID:         $Id$
    Author:     David von Oheimb
    Copyright   1999 TU Muenchen

Some auxiliary definitions.
*)

JBasis = Main + 

constdefs

  unique  :: "('a \\<times> 'b) list \\<Rightarrow> bool"
 "unique  \\<equiv> nodups \\<circ> map fst"

end
