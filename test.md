

##### IsEmpty

```
let isEmpty = 
	let l2 = (v:int list) true in
	(b0:bool) (fun (u_0:'fa) -> fun (dt:'fa) -> fun (u_0:'fa) ->
    (
     (
true &&
not      (list_member l2 u_0)
     ) &&
     (
      (list_member dt u_0) ||
not      (list_head dt u_0)
     )
    ))
```


##### StackPush

```
let stackPush = 
	let x0 = (v:int) true in
	let l0 = (v:int list) true in
	(l1:int list) (fun (u_0:'fa) -> fun (u_1:'fa) -> fun (dt:'fa) -> fun (u_0:'fa) ->
    (
     (
      (iff (list_head l1 u_0) 
       (x0==u_0)) &&
      (iff (list_member l1 u_0) 
       ((list_order l1 x0 u_0) || (list_head l1 u_0))) &&
      (iff (list_order l1 u_0 u_1) 
       (
        (list_order l0 u_0 u_1) ||
        ((list_head l1 u_0) && (list_member l0 u_1))
       ))
     ) &&
     (
      (list_member dt u_0) ||
not      (list_head dt u_0)
     )
    ))
```


##### StackTail

```
let stackTail = 
	let l4 = (v:int list) true in
	(l5:int list) (fun (u_0:'fa) -> fun (u_1:'fa) -> fun (dt:'fa) -> fun (u_0:'fa) ->
    (
     (
      (
       (
implies         (list_head l5 u_0) 
        (
         (list_member l5 u_0) &&
         (
implies           (list_order l5 u_1 u_0) 
          (
           (list_order l5 u_0 u_1) &&
           (implies (list_head l4 u_0) (list_head l4 u_1))
          )
         )
        )
       ) &&
       (
implies         (
not         (list_member l4 u_1) &&
         (
          (list_member l5 u_0) &&
not          (list_head l4 u_0)
         )
        ) 
        (list_head l5 u_0)
       )
      ) &&
      (
       (
implies         (list_member l5 u_0) 
        (
         (list_order l4 u_1 u_0) ||
         (
          (list_member l4 u_0) &&
          (
           (list_head l5 u_0) ||
           (
            (list_order l5 u_0 u_1) ||
            (
not             (list_order l4 u_0 u_1) &&
not             (list_head l4 u_1)
            )
           )
          )
         )
        )
       ) &&
       (
implies         (
         (list_order l4 u_1 u_0) ||
         (
          (list_head l5 u_0) ||
          (
           (list_order l5 u_0 u_1) ||
           (
            (u_0==u_1) &&
            (
not             (list_head l4 u_0) &&
             (list_member l4 u_0)
            )
           )
          )
         )
        ) 
        (list_member l5 u_0)
       )
      ) &&
      (
       (
implies         (list_order l5 u_0 u_1) 
        ((list_order l4 u_0 u_1) && (list_member l5 u_0))
       ) &&
       (
implies         (
         (list_order l4 u_0 u_1) &&
         (
implies           (list_head l4 u_0) 
          (
not           (list_order l4 u_1 u_0) &&
           (list_member l5 u_0)
          )
         )
        ) 
        (list_order l5 u_0 u_1)
       )
      )
     ) &&
     (
      (list_member dt u_0) ||
not      (list_head dt u_0)
     )
    ))
```


##### StackTop

```
let stackTop = 
	let l3 = (v:int list) true in
	(x1:int) (fun (u_0:'fa) -> fun (u_1:'fa) -> fun (dt:'fa) -> fun (u_0:'fa) ->
    (
     (iff (x1==u_0) 
      (list_head l3 u_0)) &&
     (
      (list_member dt u_0) ||
not      (list_head dt u_0)
     )
    ))
```



##### IsEmpty

```
let isEmpty = 
	let l2 = (v:int list) true in
	(b0:bool) (fun (u_0:'fa) -> fun (dt:'fa) -> fun (u_1:'fa) -> fun (u_0:'fa) ->
    (
     (
true &&
not      (list_member l2 u_0)
     ) &&
     (
      (
implies        (list_member dt u_1) 
       (
        (list_order dt u_0 u_1) ||
        (
         (list_head dt u_1) ||
         (
not          (list_head dt u_0) &&
          (
not           (list_next dt u_0 u_1) &&
           (
            (list_next dt u_1 u_0) ||
            (
             (u_1==u_0) ||
true
            )
           )
          )
         )
        )
       )
      ) &&
      (
implies not       (list_member dt u_1) 
       (
not        (list_head dt u_1) &&
        (
not         (list_order dt u_0 u_1) &&
         (
not          (list_order dt u_1 u_0) &&
          (
not           (list_next dt u_1 u_0) &&
           (implies (list_head dt u_0) (list_member dt u_0))
          )
         )
        )
       )
      )
     )
    ))
```


##### StackPush

```
let stackPush = 
	let x0 = (v:int) true in
	let l0 = (v:int list) true in
	(l1:int list) (fun (u_0:'fa) -> fun (u_1:'fa) -> fun (dt:'fa) -> fun (u_1:'fa) -> fun (u_0:'fa) ->
    (
     (
      (iff (list_head l1 u_0) 
       (x0==u_0)) &&
      (iff (list_member l1 u_0) 
       ((list_order l1 x0 u_0) || (list_head l1 u_0))) &&
      (iff (list_order l1 u_0 u_1) 
       (
        (list_order l0 u_0 u_1) ||
        ((list_head l1 u_0) && (list_member l0 u_1))
       ))
     ) &&
     (
      (
implies        (list_member dt u_1) 
       (
        (list_order dt u_0 u_1) ||
        (
         (list_head dt u_1) ||
         (
not          (list_head dt u_0) &&
          (
not           (list_next dt u_0 u_1) &&
           (
            (list_next dt u_1 u_0) ||
            (
             (u_1==u_0) ||
true
            )
           )
          )
         )
        )
       )
      ) &&
      (
implies not       (list_member dt u_1) 
       (
not        (list_head dt u_1) &&
        (
not         (list_order dt u_0 u_1) &&
         (
not          (list_order dt u_1 u_0) &&
          (
not           (list_next dt u_1 u_0) &&
           (implies (list_head dt u_0) (list_member dt u_0))
          )
         )
        )
       )
      )
     )
    ))
```


##### StackTail

```
let stackTail = 
	let l4 = (v:int list) true in
	(l5:int list) (fun (u_0:'fa) -> fun (u_1:'fa) -> fun (dt:'fa) -> fun (u_1:'fa) -> fun (u_0:'fa) ->
    (
     (
      (
       (
implies         (list_head l5 u_0) 
        (
         (list_member l5 u_0) &&
         (
implies           (list_order l5 u_1 u_0) 
          (
           (list_order l5 u_0 u_1) &&
           (implies (list_head l4 u_0) (list_head l4 u_1))
          )
         )
        )
       ) &&
       (
implies         (
not         (list_member l4 u_1) &&
         (
          (list_member l5 u_0) &&
not          (list_head l4 u_0)
         )
        ) 
        (list_head l5 u_0)
       )
      ) &&
      (
       (
implies         (list_member l5 u_0) 
        (
         (list_order l4 u_1 u_0) ||
         (
          (list_member l4 u_0) &&
          (
           (list_head l5 u_0) ||
           (
            (list_order l5 u_0 u_1) ||
            (
not             (list_order l4 u_0 u_1) &&
not             (list_head l4 u_1)
            )
           )
          )
         )
        )
       ) &&
       (
implies         (
         (list_order l4 u_1 u_0) ||
         (
          (list_head l5 u_0) ||
          (
           (list_order l5 u_0 u_1) ||
           (
            (u_0==u_1) &&
            (
not             (list_head l4 u_0) &&
             (list_member l4 u_0)
            )
           )
          )
         )
        ) 
        (list_member l5 u_0)
       )
      ) &&
      (
       (
implies         (list_order l5 u_0 u_1) 
        ((list_order l4 u_0 u_1) && (list_member l5 u_0))
       ) &&
       (
implies         (
         (list_order l4 u_0 u_1) &&
         (
implies           (list_head l4 u_0) 
          (
not           (list_order l4 u_1 u_0) &&
           (list_member l5 u_0)
          )
         )
        ) 
        (list_order l5 u_0 u_1)
       )
      )
     ) &&
     (
      (
implies        (list_member dt u_1) 
       (
        (list_order dt u_0 u_1) ||
        (
         (list_head dt u_1) ||
         (
not          (list_head dt u_0) &&
          (
not           (list_next dt u_0 u_1) &&
           (
            (list_next dt u_1 u_0) ||
            (
             (u_1==u_0) ||
true
            )
           )
          )
         )
        )
       )
      ) &&
      (
implies not       (list_member dt u_1) 
       (
not        (list_head dt u_1) &&
        (
not         (list_order dt u_0 u_1) &&
         (
not          (list_order dt u_1 u_0) &&
          (
not           (list_next dt u_1 u_0) &&
           (implies (list_head dt u_0) (list_member dt u_0))
          )
         )
        )
       )
      )
     )
    ))
```


##### StackTop

```
let stackTop = 
	let l3 = (v:int list) true in
	(x1:int) (fun (u_0:'fa) -> fun (u_1:'fa) -> fun (dt:'fa) -> fun (u_1:'fa) -> fun (u_0:'fa) ->
    (
     (iff (x1==u_0) 
      (list_head l3 u_0)) &&
     (
      (
implies        (list_member dt u_1) 
       (
        (list_order dt u_0 u_1) ||
        (
         (list_head dt u_1) ||
         (
not          (list_head dt u_0) &&
          (
not           (list_next dt u_0 u_1) &&
           (
            (list_next dt u_1 u_0) ||
            (
             (u_1==u_0) ||
true
            )
           )
          )
         )
        )
       )
      ) &&
      (
implies not       (list_member dt u_1) 
       (
not        (list_head dt u_1) &&
        (
not         (list_order dt u_0 u_1) &&
         (
not          (list_order dt u_1 u_0) &&
          (
not           (list_next dt u_1 u_0) &&
           (implies (list_head dt u_0) (list_member dt u_0))
          )
         )
        )
       )
      )
     )
    ))
```



##### IsEmpty

```
let isEmpty = 
	let l2 = (v:int list) true in
	(b0:bool) (fun (u_0:'fa) -> fun (dt:'fa) -> fun (u_1:'fa) -> fun (u_0:'fa) ->
    (
     (
true &&
not      (list_member l2 u_0)
     ) &&
     (
      (
implies        (list_member dt u_1) 
       (
        (list_order dt u_0 u_1) ||
        (
         (list_head dt u_1) ||
         (
not          (list_head dt u_0) &&
          (
           (u_1==u_0) ||
true
          )
         )
        )
       )
      ) &&
      (
implies not       (list_member dt u_1) 
       (
not        (list_order dt u_0 u_1) &&
        (
not         (list_head dt u_1) &&
         (
          (list_member dt u_0) ||
          (
           (u_1==u_0) ||
           (
not            (list_order dt u_1 u_0) &&
not            (list_head dt u_0)
           )
          )
         )
        )
       )
      )
     )
    ))
```


##### StackPush

```
let stackPush = 
	let x0 = (v:int) true in
	let l0 = (v:int list) true in
	(l1:int list) (fun (u_0:'fa) -> fun (u_1:'fa) -> fun (dt:'fa) -> fun (u_1:'fa) -> fun (u_0:'fa) ->
    (
     (
      (iff (list_head l1 u_0) 
       (x0==u_0)) &&
      (iff (list_member l1 u_0) 
       ((list_order l1 x0 u_0) || (list_head l1 u_0))) &&
      (iff (list_order l1 u_0 u_1) 
       (
        (list_order l0 u_0 u_1) ||
        ((list_head l1 u_0) && (list_member l0 u_1))
       ))
     ) &&
     (
      (
implies        (list_member dt u_1) 
       (
        (list_order dt u_0 u_1) ||
        (
         (list_head dt u_1) ||
         (
not          (list_head dt u_0) &&
          (
           (u_1==u_0) ||
true
          )
         )
        )
       )
      ) &&
      (
implies not       (list_member dt u_1) 
       (
not        (list_order dt u_0 u_1) &&
        (
not         (list_head dt u_1) &&
         (
          (list_member dt u_0) ||
          (
           (u_1==u_0) ||
           (
not            (list_order dt u_1 u_0) &&
not            (list_head dt u_0)
           )
          )
         )
        )
       )
      )
     )
    ))
```


##### StackTail

```
let stackTail = 
	let l4 = (v:int list) true in
	(l5:int list) (fun (u_0:'fa) -> fun (u_1:'fa) -> fun (dt:'fa) -> fun (u_1:'fa) -> fun (u_0:'fa) ->
    (
     (
      (
       (
implies         (list_head l5 u_0) 
        (
         (list_member l5 u_0) &&
         (
implies           (list_order l5 u_1 u_0) 
          (
           (list_order l5 u_0 u_1) &&
           (implies (list_head l4 u_0) (list_head l4 u_1))
          )
         )
        )
       ) &&
       (
implies         (
not         (list_member l4 u_1) &&
         (
          (list_member l5 u_0) &&
not          (list_head l4 u_0)
         )
        ) 
        (list_head l5 u_0)
       )
      ) &&
      (
       (
implies         (list_member l5 u_0) 
        (
         (list_order l4 u_1 u_0) ||
         (
          (list_member l4 u_0) &&
          (
           (list_head l5 u_0) ||
           (
            (list_order l5 u_0 u_1) ||
            (
not             (list_order l4 u_0 u_1) &&
not             (list_head l4 u_1)
            )
           )
          )
         )
        )
       ) &&
       (
implies         (
         (list_order l4 u_1 u_0) ||
         (
          (list_head l5 u_0) ||
          (
           (list_order l5 u_0 u_1) ||
           (
            (u_0==u_1) &&
            (
not             (list_head l4 u_0) &&
             (list_member l4 u_0)
            )
           )
          )
         )
        ) 
        (list_member l5 u_0)
       )
      ) &&
      (
       (
implies         (list_order l5 u_0 u_1) 
        ((list_order l4 u_0 u_1) && (list_member l5 u_0))
       ) &&
       (
implies         (
         (list_order l4 u_0 u_1) &&
         (
implies           (list_head l4 u_0) 
          (
not           (list_order l4 u_1 u_0) &&
           (list_member l5 u_0)
          )
         )
        ) 
        (list_order l5 u_0 u_1)
       )
      )
     ) &&
     (
      (
implies        (list_member dt u_1) 
       (
        (list_order dt u_0 u_1) ||
        (
         (list_head dt u_1) ||
         (
not          (list_head dt u_0) &&
          (
           (u_1==u_0) ||
true
          )
         )
        )
       )
      ) &&
      (
implies not       (list_member dt u_1) 
       (
not        (list_order dt u_0 u_1) &&
        (
not         (list_head dt u_1) &&
         (
          (list_member dt u_0) ||
          (
           (u_1==u_0) ||
           (
not            (list_order dt u_1 u_0) &&
not            (list_head dt u_0)
           )
          )
         )
        )
       )
      )
     )
    ))
```


##### StackTop

```
let stackTop = 
	let l3 = (v:int list) true in
	(x1:int) (fun (u_0:'fa) -> fun (u_1:'fa) -> fun (dt:'fa) -> fun (u_1:'fa) -> fun (u_0:'fa) ->
    (
     (iff (x1==u_0) 
      (list_head l3 u_0)) &&
     (
      (
implies        (list_member dt u_1) 
       (
        (list_order dt u_0 u_1) ||
        (
         (list_head dt u_1) ||
         (
not          (list_head dt u_0) &&
          (
           (u_1==u_0) ||
true
          )
         )
        )
       )
      ) &&
      (
implies not       (list_member dt u_1) 
       (
not        (list_order dt u_0 u_1) &&
        (
not         (list_head dt u_1) &&
         (
          (list_member dt u_0) ||
          (
           (u_1==u_0) ||
           (
not            (list_order dt u_1 u_0) &&
not            (list_head dt u_0)
           )
          )
         )
        )
       )
      )
     )
    ))
```



##### IsEmpty

```
let isEmpty = 
	let l2 = (v:int list) true in
	(b0:bool) (fun (u_0:'fa) -> fun (dt:'fa) -> fun (u_1:'fa) -> fun (u_0:'fa) ->
    (
     (
true &&
not      (list_member l2 u_0)
     ) &&
     (
      (
implies        (list_member dt u_1) 
       (
        (
implies          (u_1==u_0) 
         ((list_order dt u_1 u_0) || (list_once dt u_1))
        ) &&
        (
implies not         (u_1==u_0) 
         (
          (
implies            (list_once dt u_0) 
           (
            (implies (list_next dt u_0 u_1) (list_order dt u_0 u_1)) &&
            (
implies not             (list_next dt u_0 u_1) 
             (
              (
implies                (list_head dt u_1) 
               (
not                (list_head dt u_0) &&
                (
                 (list_order dt u_1 u_0) &&
                 (
implies                   (list_order dt u_0 u_1) 
not                  (list_once dt u_1)
                 )
                )
               )
              ) &&
              (
implies not               (list_head dt u_1) 
               (
                (list_next dt u_1 u_0) ||
                (
                 (list_member dt u_0) &&
                 (
                  (
implies                    (list_order dt u_1 u_0) 
not                   (list_head dt u_0)
                  ) &&
                  (
implies not                   (list_order dt u_1 u_0) 
                   (list_order dt u_0 u_1)
                  )
                 )
                )
               )
              )
             )
            )
           )
          ) &&
          (
implies not           (list_once dt u_0) 
           (
            (
implies              (list_last dt u_1) 
             (
              (list_next dt u_1 u_0) ||
              (
not               (list_last dt u_0) &&
               (
                (
implies                  (list_once dt u_1) 
                 (
                  (list_order dt u_0 u_1) ||
                  (
                   (list_head dt u_1) ||
                   (
not                    (list_member dt u_0) &&
not                    (list_order dt u_1 u_0)
                   )
                  )
                 )
                ) &&
                (
implies not                 (list_once dt u_1) 
                 (
                  (list_order dt u_1 u_0) ||
true
                 )
                )
               )
              )
             )
            ) &&
            (
implies not             (list_last dt u_1) 
             (
              (implies (list_next dt u_0 u_1) (list_order dt u_0 u_1)) &&
              (
implies not               (list_next dt u_0 u_1) 
               (
                (
implies                  (list_head dt u_0) 
                 (
                  (list_order dt u_0 u_1) &&
                  (
                   (list_member dt u_0) &&
                   (
not                    (list_head dt u_1) &&
                    (
                     (list_order dt u_1 u_0) ||
not                     (list_last dt u_0)
                    )
                   )
                  )
                 )
                ) &&
                (
implies not                 (list_head dt u_0) 
                 (
                  (
implies                    (list_head dt u_1) 
                   (
                    (list_order dt u_0 u_1) ||
                    (
                     (implies (list_last dt u_0) (list_order dt u_1 u_0)) &&
                     (
implies                       (
not                       (list_last dt u_0) &&
                       (list_next dt u_1 u_0)
                      ) 
                      ((list_member dt u_0) && (list_order dt u_1 u_0))
                     )
                    )
                   )
                  ) &&
                  (
implies not                   (list_head dt u_1) 
                   (
                    (list_last dt u_0) ||
                    (
                     (list_next dt u_1 u_0) ||
                     (
not                      (list_order dt u_0 u_1) &&
                      (
implies                        (list_once dt u_1) 
true
                      )
                     )
                    )
                   )
                  )
                 )
                )
               )
              )
             )
            )
           )
          )
         )
        )
       )
      ) &&
      (
implies not       (list_member dt u_1) 
       (
        (
implies          (list_member dt u_0) 
         (
not          (list_order dt u_0 u_1) &&
          (
not           (list_once dt u_1) &&
           (
not            (list_order dt u_1 u_0) &&
            (
not             (list_head dt u_1) &&
             (
not              (u_1==u_0) &&
              (
not               (list_last dt u_1) &&
               (
implies                 ((list_once dt u_0) && (list_head dt u_0)) 
                (
                 (list_last dt u_0) ||
                 (
not                  (list_next dt u_1 u_0) &&
not                  (list_next dt u_0 u_1)
                 )
                )
               )
              )
             )
            )
           )
          )
         )
        ) &&
        (
implies not         (list_member dt u_0) 
         (
not          (list_last dt u_1) &&
          (
not           (list_order dt u_0 u_1) &&
           (
not            (list_once dt u_1) &&
            (
not             (list_last dt u_0) &&
             (
not              (list_order dt u_1 u_0) &&
              (
not               (list_once dt u_0) &&
               (
not                (list_head dt u_1) &&
not                (list_next dt u_1 u_0)
               )
              )
             )
            )
           )
          )
         )
        )
       )
      )
     )
    ))
```


##### StackPush

```
let stackPush = 
	let x0 = (v:int) true in
	let l0 = (v:int list) true in
	(l1:int list) (fun (u_0:'fa) -> fun (u_1:'fa) -> fun (dt:'fa) -> fun (u_1:'fa) -> fun (u_0:'fa) ->
    (
     (
      (iff (list_head l1 u_0) 
       (x0==u_0)) &&
      (iff (list_member l1 u_0) 
       ((list_order l1 x0 u_0) || (list_head l1 u_0))) &&
      (iff (list_order l1 u_0 u_1) 
       (
        (list_order l0 u_0 u_1) ||
        ((list_head l1 u_0) && (list_member l0 u_1))
       ))
     ) &&
     (
      (
implies        (list_member dt u_1) 
       (
        (
implies          (u_1==u_0) 
         ((list_order dt u_1 u_0) || (list_once dt u_1))
        ) &&
        (
implies not         (u_1==u_0) 
         (
          (
implies            (list_once dt u_0) 
           (
            (implies (list_next dt u_0 u_1) (list_order dt u_0 u_1)) &&
            (
implies not             (list_next dt u_0 u_1) 
             (
              (
implies                (list_head dt u_1) 
               (
not                (list_head dt u_0) &&
                (
                 (list_order dt u_1 u_0) &&
                 (
implies                   (list_order dt u_0 u_1) 
not                  (list_once dt u_1)
                 )
                )
               )
              ) &&
              (
implies not               (list_head dt u_1) 
               (
                (list_next dt u_1 u_0) ||
                (
                 (list_member dt u_0) &&
                 (
                  (
implies                    (list_order dt u_1 u_0) 
not                   (list_head dt u_0)
                  ) &&
                  (
implies not                   (list_order dt u_1 u_0) 
                   (list_order dt u_0 u_1)
                  )
                 )
                )
               )
              )
             )
            )
           )
          ) &&
          (
implies not           (list_once dt u_0) 
           (
            (
implies              (list_last dt u_1) 
             (
              (list_next dt u_1 u_0) ||
              (
not               (list_last dt u_0) &&
               (
                (
implies                  (list_once dt u_1) 
                 (
                  (list_order dt u_0 u_1) ||
                  (
                   (list_head dt u_1) ||
                   (
not                    (list_member dt u_0) &&
not                    (list_order dt u_1 u_0)
                   )
                  )
                 )
                ) &&
                (
implies not                 (list_once dt u_1) 
                 (
                  (list_order dt u_1 u_0) ||
true
                 )
                )
               )
              )
             )
            ) &&
            (
implies not             (list_last dt u_1) 
             (
              (implies (list_next dt u_0 u_1) (list_order dt u_0 u_1)) &&
              (
implies not               (list_next dt u_0 u_1) 
               (
                (
implies                  (list_head dt u_0) 
                 (
                  (list_order dt u_0 u_1) &&
                  (
                   (list_member dt u_0) &&
                   (
not                    (list_head dt u_1) &&
                    (
                     (list_order dt u_1 u_0) ||
not                     (list_last dt u_0)
                    )
                   )
                  )
                 )
                ) &&
                (
implies not                 (list_head dt u_0) 
                 (
                  (
implies                    (list_head dt u_1) 
                   (
                    (list_order dt u_0 u_1) ||
                    (
                     (implies (list_last dt u_0) (list_order dt u_1 u_0)) &&
                     (
implies                       (
not                       (list_last dt u_0) &&
                       (list_next dt u_1 u_0)
                      ) 
                      ((list_member dt u_0) && (list_order dt u_1 u_0))
                     )
                    )
                   )
                  ) &&
                  (
implies not                   (list_head dt u_1) 
                   (
                    (list_last dt u_0) ||
                    (
                     (list_next dt u_1 u_0) ||
                     (
not                      (list_order dt u_0 u_1) &&
                      (
implies                        (list_once dt u_1) 
true
                      )
                     )
                    )
                   )
                  )
                 )
                )
               )
              )
             )
            )
           )
          )
         )
        )
       )
      ) &&
      (
implies not       (list_member dt u_1) 
       (
        (
implies          (list_member dt u_0) 
         (
not          (list_order dt u_0 u_1) &&
          (
not           (list_once dt u_1) &&
           (
not            (list_order dt u_1 u_0) &&
            (
not             (list_head dt u_1) &&
             (
not              (u_1==u_0) &&
              (
not               (list_last dt u_1) &&
               (
implies                 ((list_once dt u_0) && (list_head dt u_0)) 
                (
                 (list_last dt u_0) ||
                 (
not                  (list_next dt u_1 u_0) &&
not                  (list_next dt u_0 u_1)
                 )
                )
               )
              )
             )
            )
           )
          )
         )
        ) &&
        (
implies not         (list_member dt u_0) 
         (
not          (list_last dt u_1) &&
          (
not           (list_order dt u_0 u_1) &&
           (
not            (list_once dt u_1) &&
            (
not             (list_last dt u_0) &&
             (
not              (list_order dt u_1 u_0) &&
              (
not               (list_once dt u_0) &&
               (
not                (list_head dt u_1) &&
not                (list_next dt u_1 u_0)
               )
              )
             )
            )
           )
          )
         )
        )
       )
      )
     )
    ))
```


##### StackTail

```
let stackTail = 
	let l4 = (v:int list) true in
	(l5:int list) (fun (u_0:'fa) -> fun (u_1:'fa) -> fun (dt:'fa) -> fun (u_1:'fa) -> fun (u_0:'fa) ->
    (
     (
      (
       (
implies         (list_head l5 u_0) 
        (
         (list_member l5 u_0) &&
         (
implies           (list_order l5 u_1 u_0) 
          (
           (list_order l5 u_0 u_1) &&
           (implies (list_head l4 u_0) (list_head l4 u_1))
          )
         )
        )
       ) &&
       (
implies         (
not         (list_member l4 u_1) &&
         (
          (list_member l5 u_0) &&
not          (list_head l4 u_0)
         )
        ) 
        (list_head l5 u_0)
       )
      ) &&
      (
       (
implies         (list_member l5 u_0) 
        (
         (list_order l4 u_1 u_0) ||
         (
          (list_member l4 u_0) &&
          (
           (list_head l5 u_0) ||
           (
            (list_order l5 u_0 u_1) ||
            (
not             (list_order l4 u_0 u_1) &&
not             (list_head l4 u_1)
            )
           )
          )
         )
        )
       ) &&
       (
implies         (
         (list_order l4 u_1 u_0) ||
         (
          (list_head l5 u_0) ||
          (
           (list_order l5 u_0 u_1) ||
           (
            (u_0==u_1) &&
            (
not             (list_head l4 u_0) &&
             (list_member l4 u_0)
            )
           )
          )
         )
        ) 
        (list_member l5 u_0)
       )
      ) &&
      (
       (
implies         (list_order l5 u_0 u_1) 
        ((list_order l4 u_0 u_1) && (list_member l5 u_0))
       ) &&
       (
implies         (
         (list_order l4 u_0 u_1) &&
         (
implies           (list_head l4 u_0) 
          (
not           (list_order l4 u_1 u_0) &&
           (list_member l5 u_0)
          )
         )
        ) 
        (list_order l5 u_0 u_1)
       )
      )
     ) &&
     (
      (
implies        (list_member dt u_1) 
       (
        (
implies          (u_1==u_0) 
         ((list_order dt u_1 u_0) || (list_once dt u_1))
        ) &&
        (
implies not         (u_1==u_0) 
         (
          (
implies            (list_once dt u_0) 
           (
            (implies (list_next dt u_0 u_1) (list_order dt u_0 u_1)) &&
            (
implies not             (list_next dt u_0 u_1) 
             (
              (
implies                (list_head dt u_1) 
               (
not                (list_head dt u_0) &&
                (
                 (list_order dt u_1 u_0) &&
                 (
implies                   (list_order dt u_0 u_1) 
not                  (list_once dt u_1)
                 )
                )
               )
              ) &&
              (
implies not               (list_head dt u_1) 
               (
                (list_next dt u_1 u_0) ||
                (
                 (list_member dt u_0) &&
                 (
                  (
implies                    (list_order dt u_1 u_0) 
not                   (list_head dt u_0)
                  ) &&
                  (
implies not                   (list_order dt u_1 u_0) 
                   (list_order dt u_0 u_1)
                  )
                 )
                )
               )
              )
             )
            )
           )
          ) &&
          (
implies not           (list_once dt u_0) 
           (
            (
implies              (list_last dt u_1) 
             (
              (list_next dt u_1 u_0) ||
              (
not               (list_last dt u_0) &&
               (
                (
implies                  (list_once dt u_1) 
                 (
                  (list_order dt u_0 u_1) ||
                  (
                   (list_head dt u_1) ||
                   (
not                    (list_member dt u_0) &&
not                    (list_order dt u_1 u_0)
                   )
                  )
                 )
                ) &&
                (
implies not                 (list_once dt u_1) 
                 (
                  (list_order dt u_1 u_0) ||
true
                 )
                )
               )
              )
             )
            ) &&
            (
implies not             (list_last dt u_1) 
             (
              (implies (list_next dt u_0 u_1) (list_order dt u_0 u_1)) &&
              (
implies not               (list_next dt u_0 u_1) 
               (
                (
implies                  (list_head dt u_0) 
                 (
                  (list_order dt u_0 u_1) &&
                  (
                   (list_member dt u_0) &&
                   (
not                    (list_head dt u_1) &&
                    (
                     (list_order dt u_1 u_0) ||
not                     (list_last dt u_0)
                    )
                   )
                  )
                 )
                ) &&
                (
implies not                 (list_head dt u_0) 
                 (
                  (
implies                    (list_head dt u_1) 
                   (
                    (list_order dt u_0 u_1) ||
                    (
                     (implies (list_last dt u_0) (list_order dt u_1 u_0)) &&
                     (
implies                       (
not                       (list_last dt u_0) &&
                       (list_next dt u_1 u_0)
                      ) 
                      ((list_member dt u_0) && (list_order dt u_1 u_0))
                     )
                    )
                   )
                  ) &&
                  (
implies not                   (list_head dt u_1) 
                   (
                    (list_last dt u_0) ||
                    (
                     (list_next dt u_1 u_0) ||
                     (
not                      (list_order dt u_0 u_1) &&
                      (
implies                        (list_once dt u_1) 
true
                      )
                     )
                    )
                   )
                  )
                 )
                )
               )
              )
             )
            )
           )
          )
         )
        )
       )
      ) &&
      (
implies not       (list_member dt u_1) 
       (
        (
implies          (list_member dt u_0) 
         (
not          (list_order dt u_0 u_1) &&
          (
not           (list_once dt u_1) &&
           (
not            (list_order dt u_1 u_0) &&
            (
not             (list_head dt u_1) &&
             (
not              (u_1==u_0) &&
              (
not               (list_last dt u_1) &&
               (
implies                 ((list_once dt u_0) && (list_head dt u_0)) 
                (
                 (list_last dt u_0) ||
                 (
not                  (list_next dt u_1 u_0) &&
not                  (list_next dt u_0 u_1)
                 )
                )
               )
              )
             )
            )
           )
          )
         )
        ) &&
        (
implies not         (list_member dt u_0) 
         (
not          (list_last dt u_1) &&
          (
not           (list_order dt u_0 u_1) &&
           (
not            (list_once dt u_1) &&
            (
not             (list_last dt u_0) &&
             (
not              (list_order dt u_1 u_0) &&
              (
not               (list_once dt u_0) &&
               (
not                (list_head dt u_1) &&
not                (list_next dt u_1 u_0)
               )
              )
             )
            )
           )
          )
         )
        )
       )
      )
     )
    ))
```


##### StackTop

```
let stackTop = 
	let l3 = (v:int list) true in
	(x1:int) (fun (u_0:'fa) -> fun (u_1:'fa) -> fun (dt:'fa) -> fun (u_1:'fa) -> fun (u_0:'fa) ->
    (
     (iff (x1==u_0) 
      (list_head l3 u_0)) &&
     (
      (
implies        (list_member dt u_1) 
       (
        (
implies          (u_1==u_0) 
         ((list_order dt u_1 u_0) || (list_once dt u_1))
        ) &&
        (
implies not         (u_1==u_0) 
         (
          (
implies            (list_once dt u_0) 
           (
            (implies (list_next dt u_0 u_1) (list_order dt u_0 u_1)) &&
            (
implies not             (list_next dt u_0 u_1) 
             (
              (
implies                (list_head dt u_1) 
               (
not                (list_head dt u_0) &&
                (
                 (list_order dt u_1 u_0) &&
                 (
implies                   (list_order dt u_0 u_1) 
not                  (list_once dt u_1)
                 )
                )
               )
              ) &&
              (
implies not               (list_head dt u_1) 
               (
                (list_next dt u_1 u_0) ||
                (
                 (list_member dt u_0) &&
                 (
                  (
implies                    (list_order dt u_1 u_0) 
not                   (list_head dt u_0)
                  ) &&
                  (
implies not                   (list_order dt u_1 u_0) 
                   (list_order dt u_0 u_1)
                  )
                 )
                )
               )
              )
             )
            )
           )
          ) &&
          (
implies not           (list_once dt u_0) 
           (
            (
implies              (list_last dt u_1) 
             (
              (list_next dt u_1 u_0) ||
              (
not               (list_last dt u_0) &&
               (
                (
implies                  (list_once dt u_1) 
                 (
                  (list_order dt u_0 u_1) ||
                  (
                   (list_head dt u_1) ||
                   (
not                    (list_member dt u_0) &&
not                    (list_order dt u_1 u_0)
                   )
                  )
                 )
                ) &&
                (
implies not                 (list_once dt u_1) 
                 (
                  (list_order dt u_1 u_0) ||
true
                 )
                )
               )
              )
             )
            ) &&
            (
implies not             (list_last dt u_1) 
             (
              (implies (list_next dt u_0 u_1) (list_order dt u_0 u_1)) &&
              (
implies not               (list_next dt u_0 u_1) 
               (
                (
implies                  (list_head dt u_0) 
                 (
                  (list_order dt u_0 u_1) &&
                  (
                   (list_member dt u_0) &&
                   (
not                    (list_head dt u_1) &&
                    (
                     (list_order dt u_1 u_0) ||
not                     (list_last dt u_0)
                    )
                   )
                  )
                 )
                ) &&
                (
implies not                 (list_head dt u_0) 
                 (
                  (
implies                    (list_head dt u_1) 
                   (
                    (list_order dt u_0 u_1) ||
                    (
                     (implies (list_last dt u_0) (list_order dt u_1 u_0)) &&
                     (
implies                       (
not                       (list_last dt u_0) &&
                       (list_next dt u_1 u_0)
                      ) 
                      ((list_member dt u_0) && (list_order dt u_1 u_0))
                     )
                    )
                   )
                  ) &&
                  (
implies not                   (list_head dt u_1) 
                   (
                    (list_last dt u_0) ||
                    (
                     (list_next dt u_1 u_0) ||
                     (
not                      (list_order dt u_0 u_1) &&
                      (
implies                        (list_once dt u_1) 
true
                      )
                     )
                    )
                   )
                  )
                 )
                )
               )
              )
             )
            )
           )
          )
         )
        )
       )
      ) &&
      (
implies not       (list_member dt u_1) 
       (
        (
implies          (list_member dt u_0) 
         (
not          (list_order dt u_0 u_1) &&
          (
not           (list_once dt u_1) &&
           (
not            (list_order dt u_1 u_0) &&
            (
not             (list_head dt u_1) &&
             (
not              (u_1==u_0) &&
              (
not               (list_last dt u_1) &&
               (
implies                 ((list_once dt u_0) && (list_head dt u_0)) 
                (
                 (list_last dt u_0) ||
                 (
not                  (list_next dt u_1 u_0) &&
not                  (list_next dt u_0 u_1)
                 )
                )
               )
              )
             )
            )
           )
          )
         )
        ) &&
        (
implies not         (list_member dt u_0) 
         (
not          (list_last dt u_1) &&
          (
not           (list_order dt u_0 u_1) &&
           (
not            (list_once dt u_1) &&
            (
not             (list_last dt u_0) &&
             (
not              (list_order dt u_1 u_0) &&
              (
not               (list_once dt u_0) &&
               (
not                (list_head dt u_1) &&
not                (list_next dt u_1 u_0)
               )
              )
             )
            )
           )
          )
         )
        )
       )
      )
     )
    ))
```

