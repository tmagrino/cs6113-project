Require Export syntax.
Require Export Arith.
Require Export Arith.EqNat.  (* Contains [beq_nat], among other things *)

Inductive environment : Type :=
| Empty_Env : environment
| Env : (variable_name * value) -> environment -> environment.

Fixpoint extract_num (var : variable_name) : nat := 
  match var with
    | Var n => n
  end.

Fixpoint names_equal (n1 : variable_name) (n2 : variable_name) : bool := 
  match n1 with
      | Var m1 => (match n2 with | Var m2 => (beq_nat m1 m2) end)
  end.

(* better plan: no indirection permitted.  env only ever identifier-values to non-identifier values.*)
Fixpoint find_in_env (key : variable_name) (env : environment) : value := 
  match env with 
    | Empty_Env => (Void (Simple_Type Bottom_t Low_Label))
    | Env (vname, val) rst => 
      if (names_equal key vname) then val
      else find_in_env key rst
  end.

Fixpoint reduce_identifier (id : value) (env : environment) : value := 
  match id with
    | Identifier t v => find_in_env v env
    | _ => id
  end.

Fixpoint env_cons (id : variable_name) (bind : value) (env : environment) : environment :=
  match id with 
      | Var v => Env (id, (reduce_identifier bind env)) env
  end.


Function right_branch (expr : expression) {struct expr} := 
  match expr with 
    | Expression_Evaluation_Pair l r => (right_branch r)
    | Value v => Value (right_branch_val v)
    | Application f a => Application (right_branch_val f) (right_branch_val a)
    | Let_Bind nm vl e => Let_Bind nm (right_branch_val vl) (right_branch e)
    | If1 t b1 b2 => If1 (right_branch_val t) (right_branch b1) (right_branch b2)
  end

with right_branch_val (val : value) {struct val} :=
  match val with 
    | Identifier t vn => val
    | Unit t => val
    | Integer _ _ => val
    | Void _ => val
    | Fix t f a b => Fix t f a (right_branch b)
    | Value_Evaluation_Pair t l r => (right_branch_val r)
  end.

Function left_branch (expr : expression) {struct expr} := 
  match expr with 
    | Expression_Evaluation_Pair l r => (left_branch r)
    | Value v => Value (left_branch_val v)
    | Application f a => Application (left_branch_val f) (left_branch_val a)
    | Let_Bind nm vl e => Let_Bind nm (left_branch_val vl) (left_branch e)
    | If1 t b1 b2 => If1 (left_branch_val t) (left_branch b1) (left_branch b2)
  end

with left_branch_val (val : value) {struct val} :=
  match val with 
    | Identifier t vn => val
    | Unit t => val
    | Integer _ _ => val
    | Void _ => val
    | Fix t f a b => Fix t f a (left_branch b)
    | Value_Evaluation_Pair t l r => (left_branch_val r)
  end.

Fixpoint get_type (val : value) : type := 
  match val with 
    | Identifier t _ => t
    | Unit t => t
    | Integer t _ => t
    | Void t => t
    | Fix t f a b => t
    | Value_Evaluation_Pair t l r => t
  end.


(* big-step semantics of the language *)
(* since our non-interference proof is of the form 
"Iff computation terminates with a low type, it terminates with a single value"
We don't actually have to prove any properties of step_bound in the reduction rules
(we allow divergence) *)
Fixpoint reduction_rules (env : environment) (expr : expression) (recursion_bound : nat) (step_bound : nat) : (option value) :=
  match step_bound with 
    | S sb => 
      (match expr with 
         | Value v => Some (reduce_identifier v env)
         | Application f a => 
           (match (reduce_identifier f env) with
              | Value_Evaluation_Pair t l r => 
                let new_expr := (Expression_Evaluation_Pair 
                                   (Application l (left_branch_val a)) 
                                   (Application r (right_branch_val a))) in
                reduction_rules env new_expr recursion_bound sb
              | Fix type fname argname fexpr => 
                let new_env := (env_cons fname f 
                                         (env_cons argname a env)) in
                (match recursion_bound with 
                   | 0 => None (* failed, bottom-out *)
                   | S n => reduction_rules new_env fexpr n sb
                 end)
              | _ => None
            end)
         | Let_Bind lname lvalue lexpr => reduction_rules (env_cons lname lvalue env) lexpr recursion_bound sb
         | If1 test thendo elsedo => 
           (match (reduce_identifier test env) with
              | Integer t val => if beq_nat val 1 then reduction_rules env thendo recursion_bound sb 
                                 else reduction_rules env elsedo recursion_bound sb
              | Value_Evaluation_Pair t l r=> 
                let new_expr := (Expression_Evaluation_Pair (If1 l (left_branch thendo) (left_branch elsedo)) 
                                                            (If1 r (right_branch thendo) (right_branch elsedo))) in
                reduction_rules env new_expr recursion_bound sb
              | _ => reduction_rules env elsedo recursion_bound sb
            end
           ) 
         | Expression_Evaluation_Pair l r => 
           let new_left := (reduction_rules env l recursion_bound sb) in
           let new_right := (reduction_rules env r recursion_bound sb) in
           (match new_left with
              | None => None
              | Some nl => (match new_right with 
                              | None => None
                              | Some nr => 
                                let t := (get_type nl) in
                                Some (Value_Evaluation_Pair t nl nr)
                            end)
            end)
                                                                   
       end )
    | 0 => None (* we will prove that this case never fires *)
  end.