! nlls_module :: a nonlinear least squares solver

module nlls_module

  implicit none

  integer, parameter :: wp = kind(1.0d0)
  integer, parameter :: long = selected_int_kind(8)
  real (kind = wp), parameter :: tenm5 = 1.0e-5
  real (kind = wp), parameter :: tenm8 = 1.0e-8
  real (kind = wp), parameter :: epsmch = epsilon(1.0_wp)
  real (kind = wp), parameter :: hundred = 100.0
  real (kind = wp), parameter :: ten = 10.0
  real (kind = wp), parameter :: point9 = 0.9
  real (kind = wp), parameter :: zero = 0.0
  real (kind = wp), parameter :: one = 1.0
  real (kind = wp), parameter :: two = 2.0
  real (kind = wp), parameter :: half = 0.5
  real (kind = wp), parameter :: sixteenth = 0.0625

  
  TYPE, PUBLIC :: NLLS_control_type
     
!   error and warning diagnostics occur on stream error 
     
     INTEGER :: error = 6

!   general output occurs on stream out

     INTEGER :: out = 6

!   the level of output required. <= 0 gives no output, = 1 gives a one-line
!    summary for every iteration, = 2 gives a summary of the inner iteration
!    for each iteration, >= 3 gives increasingly verbose (debugging) output

     INTEGER :: print_level = 0

!   any printing will start on this iteration

!$$     INTEGER :: start_print = - 1

!   any printing will stop on this iteration

!$$     INTEGER :: stop_print = - 1

!   the number of iterations between printing

!$$     INTEGER :: print_gap = 1

!   the maximum number of iterations performed

     INTEGER :: maxit = 100

!   removal of the file alive_file from unit alive_unit terminates execution

!$$     INTEGER :: alive_unit = 40
!$$     CHARACTER ( LEN = 30 ) :: alive_file = 'ALIVE.d'

!   non-monotone <= 0 monotone strategy used, anything else non-monotone
!     strategy with this history length used

!$$     INTEGER :: non_monotone = 1

!   specify the model used. Possible values are
!
!      0  dynamic (*not yet implemented*)
!      1  first-order (no Hessian)
!      2  second-order (exact Hessian)
!      3  barely second-order (identity Hessian)
!      4  secant second-order (sparsity-based)
!      5  secant second-order (limited-memory BFGS, with %lbfgs_vectors history)
!      6  secant second-order (limited-memory SR1, with %lbfgs_vectors history)

     INTEGER :: model = 1

!   specify the norm used. The norm is defined via ||v||^2 = v^T P v,
!    and will define the preconditioner used for iterative methods.
!    Possible values for P are
!
!     -3  user's own norm
!     -2  P = limited-memory BFGS matrix (with %lbfgs_vectors history)
!     -1  identity (= Euclidan two-norm)
!      0  automatic (*not yet implemented*)
!      1  diagonal, P = diag( max( Hessian, %min_diagonal ) )
!      2  banded, P = band( Hessian ) with semi-bandwidth %semi_bandwidth
!      3  re-ordered band, P=band(order(A)) with semi-bandwidth %semi_bandwidth
!      4  full factorization, P = Hessian, Schnabel-Eskow modification
!      5  full factorization, P = Hessian, GMPS modification (*not yet *)
!      6  incomplete factorization of Hessian, Lin-More'
!      7  incomplete factorization of Hessian, HSL_MI28
!      8  incomplete factorization of Hessian, Munskgaard (*not yet *)
!      9  expanding band of Hessian (*not yet implemented*)


     INTEGER :: nlls_method = 1

!   specify the method used to solve the trust-region sub problem
!      1 Powell's dogleg
!      2 AINT method (of Yuji Nat.)
!      3 More-Sorensen
!      ...


!$$     INTEGER :: norm = 1

!   specify the semi-bandwidth of the band matrix P if required

!$$     INTEGER :: semi_bandwidth = 5

!   number of vectors used by the L-BFGS matrix P if required

!$$     INTEGER :: lbfgs_vectors = 10

!   number of vectors used by the sparsity-based secant Hessian if required

!$$     INTEGER :: max_dxg = 100

!   number of vectors used by the Lin-More' incomplete factorization 
!    matrix P if required

!$$     INTEGER :: icfs_vectors = 10

!  the maximum number of fill entries within each column of the incomplete 
!  factor L computed by HSL_MI28. In general, increasing mi28_lsize improves
!  the quality of the preconditioner but increases the time to compute
!  and then apply the preconditioner. Values less than 0 are treated as 0

!$$     INTEGER :: mi28_lsize = 10

!  the maximum number of entries within each column of the strictly lower 
!  triangular matrix R used in the computation of the preconditioner by 
!  HSL_MI28.  Rank-1 arrays of size mi28_rsize *  n are allocated internally 
!  to hold R. Thus the amount of memory used, as well as the amount of work
!  involved in computing the preconditioner, depends on mi28_rsize. Setting
!  mi28_rsize > 0 generally leads to a higher quality preconditioner than
!  using mi28_rsize = 0, and choosing mi28_rsize >= mi28_lsize is generally 
!  recommended

!$$     INTEGER :: mi28_rsize = 10

!  which linear least squares solver should we use?
     
     INTEGER :: lls_solver
        
!   overall convergence tolerances. The iteration will terminate when the
!     norm of the gradient of the objective function is smaller than 
!       MAX( %stop_g_absolute, %stop_g_relative * norm of the initial gradient
!     or if the step is less than %stop_s

     REAL ( KIND = wp ) :: stop_g_absolute = tenm5
     REAL ( KIND = wp ) :: stop_g_relative = tenm8
!$$     REAL ( KIND = wp ) :: stop_s = epsmch

!   try to pick a good initial trust-region radius using %advanced_start
!    iterates of a variant on the strategy of Sartenaer SISC 18(6)1990:1788-1803
     
!$$     INTEGER :: advanced_start = 0
     
!   initial value for the trust-region radius (-ve => ||g_0||)
     
     REAL ( KIND = wp ) :: initial_radius = hundred
     
!   maximum permitted trust-region radius

     REAL ( KIND = wp ) :: maximum_radius = ten ** 8

!   a potential iterate will only be accepted if the actual decrease
!    f - f(x_new) is larger than %eta_successful times that predicted
!    by a quadratic model of the decrease. The trust-region radius will be
!    increased if this relative decrease is greater than %eta_very_successful
!    but smaller than %eta_too_successful

     REAL ( KIND = wp ) :: eta_successful = ten ** ( - 8 )
     REAL ( KIND = wp ) :: eta_very_successful = point9
     REAL ( KIND = wp ) :: eta_too_successful = two

!   on very successful iterations, the trust-region radius will be increased by
!    the factor %radius_increase, while if the iteration is unsuccessful, the 
!    radius will be decreased by a factor %radius_reduce but no more than
!    %radius_reduce_max

     REAL ( KIND = wp ) :: radius_increase = two
     REAL ( KIND = wp ) :: radius_reduce = half
     REAL ( KIND = wp ) :: radius_reduce_max = sixteenth
       
!   the smallest value the objective function may take before the problem
!    is marked as unbounded

!$$     REAL ( KIND = wp ) :: obj_unbounded = - epsmch ** ( - 2 )

!   the maximum CPU time allowed (-ve means infinite)
     
!$$     REAL ( KIND = wp ) :: cpu_time_limit = - one

!   the maximum elapsed clock time allowed (-ve means infinite)

!$$     REAL ( KIND = wp ) :: clock_time_limit = - one
       
!   is the Hessian matrix of second derivatives available or is access only
!    via matrix-vector products?

!$$     LOGICAL :: hessian_available = .TRUE.

!   use a direct (factorization) or (preconditioned) iterative method to 
!    find the search direction

!$$     LOGICAL :: subproblem_direct = .FALSE.

!   use a factorization (dsyev) to find the smallest eigenvalue for the subproblem
!    solve? (alternative is an iterative method (dsyevx)
     LOGICAL :: subproblem_eig_fact = .FALSE.
     

!   is a retrospective strategy to be used to update the trust-region radius?

!$$     LOGICAL :: retrospective_trust_region = .FALSE.

!   should the radius be renormalized to account for a change in preconditioner?

!$$     LOGICAL :: renormalize_radius = .FALSE.

!   if %space_critical true, every effort will be made to use as little
!    space as possible. This may result in longer computation time
     
!$$     LOGICAL :: space_critical = .FALSE.
       
!   if %deallocate_error_fatal is true, any array/pointer deallocation error
!     will terminate execution. Otherwise, computation will continue

!$$     LOGICAL :: deallocate_error_fatal = .FALSE.

!  all output lines will be prefixed by %prefix(2:LEN(TRIM(%prefix))-1)
!   where %prefix contains the required string enclosed in 
!   quotes, e.g. "string" or 'string'

!$$     CHARACTER ( LEN = 30 ) :: prefix = '""                            '
     
  END TYPE NLLS_control_type

!  - - - - - - - - - - - - - - - - - - - - - - - 
!   inform derived type with component defaults
!  - - - - - - - - - - - - - - - - - - - - - - - 

  TYPE, PUBLIC :: NLLS_inform_type
     
!  return status
!   1 -- maximum number of iterations reached
!   2 -- error from evaluating a function/Jacobian/Hessian
!   3 -- unsupported choice of model
!   4 -- error return from an lapack routine
     
     INTEGER :: status = 0
     
!  the status of the last attempted allocation/deallocation

     INTEGER :: alloc_status = 0

!  the name of the array for which an allocation/deallocation error ocurred

!$$     CHARACTER ( LEN = 80 ) :: bad_alloc = REPEAT( ' ', 80 )

!  the total number of iterations performed
     
     INTEGER :: iter
       
!  the total number of CG iterations performed

!$$     INTEGER :: cg_iter = 0

!  the total number of evaluations of the objective function

     INTEGER :: f_eval = 0

!  the total number of evaluations of the gradient of the objective function

     INTEGER :: g_eval = 0

!  the total number of evaluations of the Hessian of the objective function
     
     INTEGER :: h_eval = 0

!  the maximum number of factorizations in a sub-problem solve

!$$     INTEGER :: factorization_max = 0

!  the return status from the factorization

!$$     INTEGER :: factorization_status = 0

!   the maximum number of entries in the factors

!$$     INTEGER ( KIND = long ) :: max_entries_factors = 0

!  the total integer workspace required for the factorization

!$$     INTEGER :: factorization_integer = - 1

!  the total real workspace required for the factorization

!$$     INTEGER :: factorization_real = - 1

!  the average number of factorizations per sub-problem solve

!$$     REAL ( KIND = wp ) :: factorization_average = zero

!  the value of the objective function at the best estimate of the solution 
!   determined by NLLS_solve

     REAL ( KIND = wp ) :: obj = HUGE( one )

!  the norm of the gradient of the objective function at the best estimate 
!   of the solution determined by NLLS_solve

     REAL ( KIND = wp ) :: norm_g = HUGE( one )

!  the total CPU time spent in the package

!$$     REAL :: cpu_total = 0.0
       
!  the CPU time spent preprocessing the problem

!$$     REAL :: cpu_preprocess = 0.0

!  the CPU time spent analysing the required matrices prior to factorization

!$$     REAL :: cpu_analyse = 0.0

!  the CPU time spent factorizing the required matrices
     
!$$     REAL :: cpu_factorize = 0.0
       
!  the CPU time spent computing the search direction

!$$     REAL :: cpu_solve = 0.0

!  the total clock time spent in the package

!$$     REAL ( KIND = wp ) :: clock_total = 0.0
       
!  the clock time spent preprocessing the problem

!$$     REAL ( KIND = wp ) :: clock_preprocess = 0.0
       
!  the clock time spent analysing the required matrices prior to factorization

!$$     REAL ( KIND = wp ) :: clock_analyse = 0.0
       
!  the clock time spent factorizing the required matrices

!$$     REAL ( KIND = wp ) :: clock_factorize = 0.0
     
!  the clock time spent computing the search direction

!$$     REAL ( KIND = wp ) :: clock_solve = 0.0

  END TYPE NLLS_inform_type

  type params_base_type
     ! deliberately empty
  end type params_base_type
  
  abstract interface
     subroutine eval_f_type(status, n, m, x, f, params)
       import :: params_base_type
       implicit none
       integer, intent(out) :: status
       integer, intent(in) :: n,m 
       double precision, dimension(*), intent(in)  :: x
       double precision, dimension(*), intent(out) :: f
       class(params_base_type), intent(in) :: params
     end subroutine eval_f_type
  end interface

  abstract interface
     subroutine eval_j_type(status, n, m, x, J, params)
       import :: params_base_type
       implicit none
       integer, intent(out) :: status
       integer, intent(in) :: n,m 
       double precision, dimension(*), intent(in)  :: x
       double precision, dimension(*), intent(out) :: J
       class(params_base_type), intent(in) :: params
     end subroutine eval_j_type
  end interface

  abstract interface
     subroutine eval_hf_type(status, n, m, x, f, h, params)
       import :: params_base_type
       implicit none
       integer, intent(out) :: status
       integer, intent(in) :: n,m 
       double precision, dimension(*), intent(in)  :: x
       double precision, dimension(*), intent(in)  :: f
       double precision, dimension(*), intent(out) :: h
       class(params_base_type), intent(in) :: params
     end subroutine eval_hf_type
  end interface


  ! define types for workspace arrays.
    
    type, private :: max_eig_work ! workspace for subroutine max_eig
       real(wp), allocatable :: alphaR(:), alphaI(:), beta(:), vr(:,:)
       real(wp), allocatable :: work(:), ew_array(:)
       integer, allocatable :: nullindex(:)
       logical, allocatable :: vecisreal(:)
    end type max_eig_work

!!$    type, private :: solve_spd_work ! workspace for subroutine solve_general
!!$       real(wp), allocatable :: A(:,:)
!!$    end type solve_spd_work

    type, private :: solve_general_work ! workspace for subroutine solve_general
       real(wp), allocatable :: A(:,:)
       integer, allocatable :: ipiv(:)
    end type solve_general_work

    type, private :: evaluate_model_work ! workspace for subroutine evaluate_model
       real(wp), allocatable :: Jd(:), Hd(:)
    end type evaluate_model_work

    type, private :: solve_LLS_work ! workspace for subroutine solve_LLS
       real(wp), allocatable :: temp(:), work(:), Jlls(:)
    end type solve_LLS_work
    
    type, private :: min_eig_symm_work ! workspace for subroutine min_eig_work
       real(wp), allocatable :: A(:,:), work(:), ew(:)
       integer, allocatable :: iwork(:), ifail(:)
    end type min_eig_symm_work
    
    type, private :: more_sorensen_work ! workspace for subroutine more_sorensen
 !      type( solve_spd_work ) :: solve_spd_ws
       real(wp), allocatable :: A(:,:), LtL(:,:), AplusSigma(:,:)
       real(wp), allocatable :: v(:), q(:), y1(:)
!       type( solve_general_work ) :: solve_general_ws
       type( min_eig_symm_work ) :: min_eig_symm_ws
    end type more_sorensen_work

    type, private :: AINT_tr_work ! workspace for subroutine AINT_tr
       type( max_eig_work ) :: max_eig_ws
       type( evaluate_model_work ) :: evaluate_model_ws
       type( solve_general_work ) :: solve_general_ws
!       type( solve_spd_work ) :: solve_spd_ws
       REAL(wp), allocatable :: A(:,:), LtL(:,:), v(:), B(:,:), p0(:), p1(:)
       REAL(wp), allocatable :: M0(:,:), M1(:,:), y(:), gtg(:,:), q(:)
    end type AINT_tr_work

    type, private :: dogleg_work ! workspace for subroutine dogleg
       type( solve_LLS_work ) :: solve_LLS_ws
       type( evaluate_model_work ) :: evaluate_model_ws
       real(wp), allocatable :: d_sd(:), d_gn(:), ghat(:), Jg(:)
    end type dogleg_work

    type, private :: calculate_step_work ! workspace for subroutine calculate_step
       type( AINT_tr_work ) :: AINT_tr_ws
       type( dogleg_work ) :: dogleg_ws
       type( more_sorensen_work ) :: more_sorensen_ws
    end type calculate_step_work

    type :: NLLS_workspace ! all workspaces called from the top level
       type ( calculate_step_work ) :: calculate_step_ws
       type ( evaluate_model_work ) :: evaluate_model_ws
    end type NLLS_workspace

contains


  SUBROUTINE RAL_NLLS( n, m, X,                   & 
                       eval_F, eval_J, eval_HF,   & 
                       params,                    &
                       status, options )
    
!  -----------------------------------------------------------------------------
!  RAL_NLLS, a fortran subroutine for finding a first-order critical
!   point (most likely, a local minimizer) of the nonlinear least-squares 
!   objective function 1/2 ||F(x)||_2^2.

!  Authors: RAL NA Group (Iain Duff, Nick Gould, Jonathan Hogg, Tyrone Rees, 
!                         Jennifer Scott)
!  -----------------------------------------------------------------------------

!   Dummy arguments

    INTEGER, INTENT( IN ) :: n, m
    REAL( wp ), DIMENSION( n ), INTENT( INOUT ) :: X
    TYPE( NLLS_inform_type ), INTENT( OUT ) :: status
    TYPE( NLLS_control_type ), INTENT( IN ) :: options
    procedure( eval_f_type ) :: eval_F
    procedure( eval_j_type ) :: eval_J
    procedure( eval_hf_type ) :: eval_HF
    class( params_base_type ) :: params
      
    integer :: jstatus=0, fstatus=0, hfstatus=0
    integer :: i
    real(wp), DIMENSION(m*n) :: J, Jnew
    real(wp), DIMENSION(m)   :: f, fnew
    real(wp), DIMENSION(n*n) :: hf, hfnew
    real(wp), DIMENSION(n)   :: d, g, Xnew
    real(wp) :: Delta, rho, normJF0, normF0, normJF, normF, md
    real(wp) :: actual_reduction, predicted_reduction

    type ( NLLS_workspace ) :: w
    
    if ( options%print_level >= 3 )  write( options%out , 3000 ) 

    call setup_workspaces(w,n,m,options,status%alloc_status)
    if (status%alloc_status > 0) goto 4000

    Delta = options%initial_radius
    
    
    call eval_F(fstatus, n, m, X, f, params)
    status%f_eval = status%f_eval + 1
    if (fstatus > 0) goto 4020
    call eval_J(jstatus, n, m, X, J, params)
    status%g_eval = status%g_eval + 1
    if (jstatus > 0) goto 4010
    select case (options%model)
    case (1) ! first-order
       hf(1:n**2) = zero
       hfnew(1:n**2) = zero
    case (2) ! second order
       call eval_HF(hfstatus, n, m, X, f, hf, params)
       status%h_eval = status%h_eval + 1
       if (hfstatus > 0) goto 4030
    case (3) ! barely second order (identity hessian)
       hf(1:n**2) = zero
       hf((/ ( (i-1)*n + i, i = 1,n ) /)) = one
       hfnew(1:n**2) = hf
    case default
       goto 4040 ! unsupported model -- return to user
    end select

    normF0 = norm2(f)
!    g = -J^Tf
    call mult_Jt(J,n,m,f,g)
    g = -g
    normJF0 = norm2(g)
    
    ! save some data 
    status%obj = 0.5 * ( normF0**2 )
    status%norm_g = normJF0
    
    main_loop: do i = 1,options%maxit
       
       if ( options%print_level >= 3 )  write( options%out , 3030 ) i
       status%iter = i

       !+++++++++++++++++++++++++++++++++++++++++++!
       ! Calculate the step                        !
       !    d                                      !   
       ! that the model thinks we should take next !
       !+++++++++++++++++++++++++++++++++++++++++++!

       call calculate_step(J,f,hf,g,n,m,Delta,d,options,status,& 
                           w%calculate_step_ws)
       if (status%status .ne. 0) goto 4000
       
       !++++++++++++++++++!
       ! Accept the step? !
       !++++++++++++++++++!

       Xnew = X + d;
       call eval_F(fstatus, n, m, Xnew, fnew, params)
       status%f_eval = status%f_eval + 1
       if (fstatus > 0) goto 4020
       call eval_J(jstatus, n, m, Xnew, Jnew, params)
       status%g_eval = status%g_eval + 1
       if (jstatus > 0) goto 4010
       select case (options%model) ! only update hessians than change..
       case (1) ! first-order
          continue
       case (2) ! second order
          call eval_HF(hfstatus, n, m, X, fnew, hfnew, params)
          status%h_eval = status%h_eval + 1
          if (hfstatus > 0) goto 4030
       case (3) ! barely second order (identity hessian)
          continue
       end select

       !++++++++++++++++++++++++++++!
       ! Get the value of the model !
       !         md                 !
       ! evaluated at the new step  !
       !++++++++++++++++++++++++++++!
       call evaluate_model(f,J,hf,d,md,m,n,options,w%evaluate_model_ws)
       
       actual_reduction = ( 0.5 * norm2(f)**2 ) - ( 0.5 * norm2(fnew)**2 )
       predicted_reduction = ( ( 0.5 * norm2(f)**2 ) - md )
       
       if ( abs(actual_reduction) < 10*epsmch ) then 
          rho = one
       else if (abs( predicted_reduction ) < 10 * epsmch ) then 
          rho = one
       else
          rho = actual_reduction / predicted_reduction
       end if

       success_rho: if (rho > options%eta_successful) then
          X = Xnew;
          J = Jnew;
          f = fnew;
          hf = hfnew;

          ! g = -J^Tf
          call mult_Jt(J,n,m,f,g)
          g = -g
          
          normF = norm2(f)
          normJF = norm2(g)
          
          ! update the stats 
          status%obj = 0.5*(normF**2)
          status%norm_g = normJF


          if (options%print_level >=3) write(options%out,3010) status%obj
          if (options%print_level >=3) write(options%out,3060) normJF/normF

          !++++++++++++++++++!
          ! Test convergence !
          !++++++++++++++++++!
          if ( normF <= options%stop_g_absolute + &
               options%stop_g_relative * normF0) then
             if (options%print_level > 0 ) write(options%out,3020) i
             return
          end if
          if ( (normJF/normF) <= options%stop_g_absolute + &
               options%stop_g_relative * (normJF0/normF0)) then
             if (options%print_level > 0 ) write(options%out,3020) i
             return
          end if
          if (options%print_level > 2 ) write(options%out,3100) rho
          
       else 
          ! print something....
          if (options%print_level > 2 ) write(options%out,3090) rho
                          
       end if success_rho
          
       !++++++++++++++++++++++!
       ! Update the TR radius !
       !++++++++++++++++++++++!
       update_tr: if ( (rho > options%eta_very_successful) &
            .and. (rho < options%eta_too_successful) ) then
          Delta = min(options%maximum_radius, options%radius_increase * Delta )
          if (options%print_level > 2) write(options%out,3040) Delta
       else if (rho < options%eta_successful) then
          Delta = max( options%radius_reduce, options%radius_reduce_max) * Delta
          if (options%print_level > 2) write(options%out,3050) Delta     
       else if (rho > options%eta_too_successful) then
          if (options%print_level > 2) write(options%out,3080) Delta 
       else
          if (options%print_level > 2) write(options%out,3070) Delta 
       end if update_tr
       
     end do main_loop

    if (options%print_level > 0 ) write(options%out,1040) 
    status%status = 1
    
    RETURN

! Non-executable statements

! print level > 0

1040 FORMAT(/,'RAL_NLLS failed to converge in the allowed number of iterations')

! print level > 1

! print level > 2
3000 FORMAT(/,'* Running RAL_NLLS *')
3010 FORMAT('0.5 ||f||^2 = ',ES12.4)
3020 FORMAT('RAL_NLLS converged at iteration ',I6)
3030 FORMAT('== Starting iteration ',i0,' ==')
3040 FORMAT('Very successful step -- increasing Delta to', ES12.4)
3050 FORMAT('Unsuccessful step -- decreasing Delta to', ES12.4)
3060 FORMAT('||J''f||/||f|| = ',ES12.4)
3070 FORMAT('Successful step -- Delta staying at', ES12.4)
3080 FORMAT('Step too successful -- Delta staying at', ES12.4)   
3090 FORMAT('Step was unsuccessful -- rho =', ES12.4)
3100 FORMAT('Step was successful -- rho =', ES12.4)
! error returns
4000 continue
    ! generic end of algorithm
    if (options%print_level > 0) then
       write(options%error,'(a)') 'Exiting RAL_NLLS'
    end if
    return

4010 continue
    ! Error in eval_J
    if (options%print_level > 0) then
       write(options%error,'(a,i0)') 'Error code from eval_J, status = ', jstatus
    end if
    status%status = 2
    goto 4000

4020 continue
    ! Error in eval_J
    if (options%print_level > 0) then
       write(options%error,'(a,i0)') 'Error code from eval_F, status = ', fstatus
    end if
    status%status = 2
    goto 4000

4030 continue
    ! Error in eval_HF
    if (options%print_level > 0) then
       write(options%error,'(a,i0)') 'Error code from eval_HF, status = ', hfstatus
    end if
    status%status = 2
    goto 4000

4040 continue 
    ! unsupported choice of model
    if (options%print_level > 0) then
       write(options%error,'(a,i0,a)') 'Error: the choice of options%model = ', &
            options%model, ' is not supported'
    end if
    status%status = 3
    goto 4000

!  End of subroutine RAL_NLLS

  END SUBROUTINE RAL_NLLS
  
  SUBROUTINE calculate_step(J,f,hf,g,n,m,Delta,d,options,status,w)
       
! -------------------------------------------------------
! calculate_step, find the next step in the optimization
! -------------------------------------------------------

     REAL(wp), intent(in) :: J(:), f(:), hf(:), g(:), Delta
     integer, intent(in)  :: n, m
     real(wp), intent(out) :: d(:)
     TYPE( NLLS_control_type ), INTENT( IN ) :: options     
     TYPE( NLLS_inform_type ), INTENT( INOUT ) :: status
     TYPE( calculate_step_work ) :: w
     select case (options%nlls_method)
        
     case (1) ! Powell's dogleg
        call dogleg(J,f,hf,g,n,m,Delta,d,options,status,w%dogleg_ws)
     case (2) ! The AINT method
        call AINT_TR(J,f,hf,n,m,Delta,d,options,status,w%AINT_tr_ws)
     case (3) ! More-Sorensen
        call more_sorensen(J,f,hf,n,m,Delta,d,options,status,w%more_sorensen_ws)
     case default
        
        if ( options%print_level > 0 ) then
           write(options%error,'(a)') 'Error: unknown value of options%nlls_method'
           write(options%error,'(a,i0)') 'options%nlls_method = ', options%nlls_method
           status%status = 110 ! fix me
        end if

     end select

   END SUBROUTINE calculate_step


   SUBROUTINE dogleg(J,f,hf,g,n,m,Delta,d,options,status,w)
! -----------------------------------------
! dogleg, implement Powell's dogleg method
! -----------------------------------------

     REAL(wp), intent(in) :: J(:), hf(:), f(:), g(:), Delta
     integer, intent(in)  :: n, m
     real(wp), intent(out) :: d(:)
     TYPE( NLLS_control_type ), INTENT( IN ) :: options
     TYPE( NLLS_inform_type ), INTENT( INOUT ) :: status
     TYPE( dogleg_work ) :: w
     
     real(wp) :: alpha, beta
     integer :: slls_status, fb_status

     !     Jg = J * g
     call mult_J(J,n,m,g,w%Jg)

     alpha = norm2(g)**2 / norm2( w%Jg )**2
       
     w%d_sd = alpha * g;

     ! Solve the linear problem...
     select case (options%model)
     case (1)
        ! linear model...
        call solve_LLS(J,f,n,m,options%lls_solver,w%d_gn,slls_status,w%solve_LLS_ws)
     case default
        if (options%print_level> 0) then
           write(options%error,'(a)') 'Error: model not supported in dogleg'
        end if
        status%status = 3
        return
     end select
     
     if (norm2(w%d_gn) <= Delta) then
        d = w%d_gn
     else if (norm2( alpha * w%d_sd ) >= Delta) then
        d = (Delta / norm2(w%d_sd) ) * w%d_sd
     else
        w%ghat = w%d_gn - alpha * w%d_sd
        call findbeta(w%d_sd,w%ghat,alpha,Delta,beta,fb_status)
        d = alpha * w%d_sd + beta * w%ghat
     end if
     
   END SUBROUTINE dogleg
     
   SUBROUTINE AINT_tr(J,f,hf,n,m,Delta,d,options,status,w)
     ! -----------------------------------------
     ! AINT_tr
     ! Solve the trust-region subproblem using 
     ! the method of ADACHI, IWATA, NAKATSUKASA and TAKEDA
     ! -----------------------------------------

     REAL(wp), intent(in) :: J(:), f(:), hf(:), Delta
     integer, intent(in)  :: n, m
     real(wp), intent(out) :: d(:)
     TYPE( NLLS_control_type ), INTENT( IN ) :: options
     TYPE( NLLS_inform_type ), INTENT( INOUT ) :: status
     type( AINT_tr_work ) :: w
        
     integer :: solve_status, find_status
     integer :: keep_p0, i, eig_info, size_hard(2)
     real(wp) :: obj_p0, obj_p1
     REAL(wp) :: norm_p0, tau, lam, eta
     REAL(wp), allocatable :: y_hardcase(:,:)
     
     ! todo..
     ! seems wasteful to have a copy of A and B in M0 and M1
     ! use a pointer?

     keep_p0 = 0
     tau = 1e-4
     obj_p0 = HUGE(wp)

     ! The code finds 
     !  min_p   v^T p + 0.5 * p^T A p
     !       s.t. ||p||_B \leq Delta
     !
     ! set A and v for the model being considered here...

     call matmult_inner(J,n,m,w%A)
     ! add any second order information...
     w%A = w%A + reshape(hf,(/n,n/))
     call mult_Jt(J,n,m,f,w%v)
        
     ! Set B to I by hand  
     ! todo: make this an option
     w%B = 0
     do i = 1,n
        w%B(i,i) = 1.0
     end do
     
     select case (options%model)
     case (1,3)
        call solve_spd(w%A,-w%v,w%LtL,w%p0,n,solve_status)!,w%solve_spd_ws)
        if (solve_status .ne. 0) goto 1010
     case default
       call solve_general(w%A,-w%v,w%p0,n,solve_status,w%solve_general_ws)
       if (solve_status .ne. 0) goto 1020
     end select
          
     call matrix_norm(w%p0,w%B,norm_p0)
     
     if (norm_p0 < Delta) then
        keep_p0 = 1;
        ! get obj_p0 : the value of the model at p0
        call evaluate_model(f,J,hf,w%p0,obj_p0,m,n,options,w%evaluate_model_ws)
     end if

     w%M0(1:n,1:n) = -w%B
     w%M0(n+1:2*n,1:n) = w%A
     w%M0(1:n,n+1:2*n) = w%A
     call outer_product(w%v,n,w%gtg) ! gtg = Jtg * Jtg^T
     w%M0(n+1:2*n,n+1:2*n) = (-1.0 / Delta**2) * w%gtg

     w%M1 = 0.0
     w%M1(n+1:2*n,1:n) = -w%B
     w%M1(1:n,n+1:2*n) = -w%B
     
     call max_eig(w%M0,w%M1,2*n,lam, w%y, eig_info, y_hardcase, w%max_eig_ws)
     if ( eig_info > 0 ) goto 1030

     if (norm2(w%y(1:n)) < tau) then
        ! Hard case
        ! overwrite H onto M0, and the outer prod onto M1...
        size_hard = shape(y_hardcase)
        call matmult_outer( matmul(w%B,y_hardcase), size_hard(2), n, w%M1(1:n,1:n))
        w%M0(1:n,1:n) = w%A(:,:) + lam*w%B(:,:) + w%M1(1:n,1:n)
        ! solve Hq + g = 0 for q
        select case (options%model) 
        case (1,3)
           call solve_spd(w%M0(1:n,1:n),-w%v,w%LtL,w%q,n,solve_status)!,w%solve_spd_ws)
        case default
          call solve_general(w%M0(1:n,1:n),-w%v,w%q,n,solve_status,w%solve_general_ws)
        end select
        ! note -- a copy of the matrix is taken on entry to the solve routines
        ! (I think..) and inside...fix

        
        ! find max eta st ||q + eta v(:,1)||_B = Delta
        call findbeta(w%q,y_hardcase(:,1),one,Delta,eta,find_status)
        if ( find_status .ne. 0 ) then
           write(*,*) 'error: no vaild beta found...'
           return
        end if
        !!!!!      ^^TODO^^    !!!!!
        ! currently assumes B = I !!
        !!!!       fixme!!      !!!!
        
        w%p1(:) = w%q(:) + eta * y_hardcase(:,1)
        
     else 
        select case (options%model)
        case (1,3)
           call solve_spd(w%A + lam*w%B,-w%v,w%LtL,w%p1,n,solve_status)!,w%solve_spd_ws)
        case default
           call solve_general(w%A + lam*w%B,-w%v,w%p1,n,solve_status,w%solve_general_ws)
        end select
        ! note -- a copy of the matrix is taken on entry to the solve routines
        ! and inside...fix
     end if
     
     ! get obj_p1 : the value of the model at p1
     call evaluate_model(f,J,hf,w%p1,obj_p1,m,n,options,w%evaluate_model_ws)

     ! what gives the smallest objective: p0 or p1?
     if (obj_p0 < obj_p1) then
        d = w%p0
     else 
        d = w%p1
     end if

     return

1010 continue 
     ! bad error return from solve_spd
     write(options%error,'(a)') 'Error in solving a linear system in AINT_TR'
     write(options%error,'(a,i0)') 'dposv returned info = ', solve_status
     status%status = 4
     return
     
1020 continue
     ! bad error return from solve_general
     write(options%error,'(a)') 'Error in solving a linear system in AINT_TR'
     write(options%error,'(a,i0)') 'dgexv returned info = ', solve_status
     status%status = 4
     return
     
1030 continue
     ! bad error return from max_eig
     write(options%error,'(a)') 'Error in the eigenvalue computation of AINT_TR'
     write(options%error,'(a,i0)') 'dggev returned info = ', eig_info
     status%status = 4
     return

   end SUBROUTINE AINT_tr

   subroutine more_sorensen(J,f,hf,n,m,Delta,d,options,status,w)
     ! -----------------------------------------
     ! more_sorensen
     ! Solve the trust-region subproblem using 
     ! the method of More and Sorensen
     !
     ! Using the implementation as in Algorithm 7.3.6
     ! of Trust Region Methods
     ! 
     ! main output :: d, the soln to the TR subproblem
     ! -----------------------------------------

     REAL(wp), intent(in) :: J(:), f(:), hf(:), Delta
     integer, intent(in)  :: n, m
     real(wp), intent(out) :: d(:)
     TYPE( NLLS_control_type ), INTENT( IN ) :: options
     TYPE( NLLS_inform_type ), INTENT( INOUT ) :: status
     type( more_sorensen_work ) :: w

     ! parameters...make these options?
     integer :: maxits 
     real(wp) :: tol
     real(wp) :: nd, nq, nr

     real(wp) :: sigma, sigma1, alpha
     real(wp) :: tiny
     integer :: solve_status, fb_status, mineig_status
     integer :: test_pd, i 
     
     ! The code finds 
     !  d = arg min_p   v^T p + 0.5 * p^T A p
     !       s.t. ||p|| \leq Delta
     !
     ! set A and v for the model being considered here...
     
     !solve_status = 0
     tiny = 1e-8
     maxits = 100
     tol = 1e-6
     ! Set A = J^T J
     call matmult_inner(J,n,m,w%A)
     ! add any second order information...
     ! so A = J^T J + HF
     w%A = w%A + reshape(hf,(/n,n/))
     ! now form v = J^T f 
     call mult_Jt(J,n,m,f,w%v)
          
     ! d = -A\v
     call solve_spd(w%A,-w%v,w%LtL,d,n,test_pd)!,w%solve_spd_ws)
     if (test_pd .eq. 0) then
        ! A is symmetric positive definite....
        sigma = zero
     else
        call min_eig_symm(w%A,n,sigma,w%y1,options,mineig_status,w%min_eig_symm_ws) 
        if (mineig_status .ne. 0) goto 1060 
        sigma = -(sigma - tiny)
        call shift_matrix(w%A,sigma,w%AplusSigma,n)
        call solve_spd(w%AplusSigma,-w%v,w%LtL,d,n,test_pd)
        if ( test_pd .ne. 0 ) then
           call min_eig_symm(w%AplusSigma,n,sigma,w%y1,options,mineig_status,w%min_eig_symm_ws) 
           write(*,*) 'new smallest eig = ', sigma
           goto 2000 ! shouldn't happen!
        end if
     end if
     
     nd = norm2(d)
     
     if (nd .le. Delta) then
        ! we're within the tr radius from the start!
        if ( abs(sigma) < tiny ) then
           ! we're good....exit
           goto 1050
        else if ( abs( nd - Delta ) < tiny ) then
           ! also good...exit
           goto 1050              
        end if
        call findbeta(d,w%y1,one,Delta,alpha,fb_status)
        if (fb_status .ne. 0 ) goto 1070  !! todo! change this error code....
        d = d + alpha * w%y1
        ! also good....exit
        goto 1050
     end if

     ! now, we're not in the trust region initally, so iterate....
     do i = 1, maxits
        if ( abs(nd - Delta) <= tol * Delta) then
           goto 1020 ! converged!
        end if
        
        w%q = d ! w%q = R'\d
        CALL DTRSM( 'Left', 'Lower', 'No Transpose', 'Non-unit', n, & 
             1, one, w%LtL, n, w%q, n )
        
        nq = norm2(w%q)
        sigma = sigma + ( (nd/nq)**2 )* ( (nd - Delta) / Delta )
        
        call shift_matrix(w%A,sigma,w%AplusSigma,n)
        call solve_spd(w%AplusSigma,-w%v,w%LtL,d,n,test_pd)
        if (test_pd .ne. 0)  goto 2010 ! shouldn't happen...
        nd = norm2(d)

     end do
     
     goto 1040
     
1010 continue 
     ! bad error return from solve_spd
     if ( options%print_level > 0 ) then
        write(options%out,'(a)') 'Error in solving a linear system in More_sorensen'
        write(options%out,'(a,i0)') 'dposv returned info = ', solve_status
     end if
     status%status = 4
     return

1020 continue
     ! Converged!
     if ( options%print_level > 3 ) then
        write(options%error,'(a,i0)') 'More-Sorensen converged at iteration', i
     end if
     return

1030 FORMAT('More-Sorensen, iteration ',I0,'. increasing sigma to ', ES12.4)
     
1040 continue
     ! maxits reached, not converged
     if ( options%print_level > 0 ) then
        write(options%error,'(a)') 'Maximum iterations reached in More-Sorensen'
        write(options%error,'(a)') 'without convergence'
     end if
     status%status = 100 ! fix me
     return

1050 continue
     if ( options%print_level > 3 ) then
        write(options%error,'(a)') 'More-Sorensen: first point within trust region'
     end if
     return

1060 continue
     if ( options%print_level > 0 ) then
        write(options%error,'(a)') 'More-Sorensen: error from lapack routine dsyev(x)'
        write(options%error,'(a,i0)') 'info = ', mineig_status
     end if
     status%status = 333

     return

1070 continue
     if ( options%print_level > 3 ) then
        write(options%error,'(a)') 'M-S: Unable to find alpha s.t. ||s + alpha v|| = Delta'
     end if
     status%status = 200

     return
     
2000 continue 
     ! bad error return from solve_spd
     if ( options%print_level > 0 ) then
        write(options%out,'(a)') 'Unexpected error in solving a linear system in More_sorensen'
        write(options%out,'(a,i0)') 'dposv returned info = ', test_pd
     end if
     status%status = 500
     return
     
2010 continue 
     ! bad error return from solve_spd
     if ( options%print_level > 0 ) then
        write(options%out,'(a,a)') 'Unexpected error in solving a linear system ', &
                                   'in More_sorensen loop'
        write(options%out,'(a,i0)') 'dposv returned info = ', test_pd
     end if
     status%status = 600
     return
     
     
   end SUBROUTINE More_sorensen
   

   SUBROUTINE solve_LLS(J,f,n,m,method,d_gn,status,w)
       
!  -----------------------------------------------------------------
!  solve_LLS, a subroutine to solve a linear least squares problem
!  -----------------------------------------------------------------

       REAL(wp), DIMENSION(:), INTENT(IN) :: J
       REAL(wp), DIMENSION(:), INTENT(IN) :: f
       INTEGER, INTENT(IN) :: method, n, m
       REAL(wp), DIMENSION(:), INTENT(OUT) :: d_gn
       INTEGER, INTENT(OUT) :: status

       character(1) :: trans = 'N'
       integer :: nrhs = 1, lwork, lda, ldb
       type( solve_LLS_work ) :: w
       
       lda = m
       ldb = max(m,n)
       w%temp(1:m) = f(1:m)
       lwork = size(w%work)
       
       w%Jlls(:) = J(:)

       call dgels(trans, m, n, nrhs, w%Jlls, lda, w%temp, ldb, w%work, lwork, status)

       d_gn = -w%temp(1:n)
              
     END SUBROUTINE solve_LLS
     
     SUBROUTINE findbeta(d_sd,ghat,alpha,Delta,beta,status)

!  -----------------------------------------------------------------
!  findbeta, a subroutine to find the optimal beta such that 
!   || d || = Delta, where d = alpha * d_sd + beta * ghat
!  -----------------------------------------------------------------

     real(wp), dimension(:), intent(in) :: d_sd, ghat
     real(wp), intent(in) :: alpha, Delta
     real(wp), intent(out) :: beta
     integer, intent(out) :: status
     
     real(wp) :: a, b, c, discriminant
     
     status = 0

     a = norm2(ghat)**2
     b = 2.0 * alpha * dot_product( ghat, d_sd)
     c = ( alpha * norm2( d_sd ) )**2 - Delta**2
     
     discriminant = b**2 - 4 * a * c
     if ( discriminant < 0) then
        status = 1
        return
     else
        beta = (-b + sqrt(discriminant)) / (2.0 * a)
     end if

     END SUBROUTINE findbeta

     
     subroutine evaluate_model(f,J,hf,d,md,m,n,options,w)
! --------------------------------------------------
! evaluate_model, evaluate the model at the point d
! --------------------------------------------------       

       real(wp), intent(in)  :: f(:), d(:), J(:), hf(:)
       integer :: m,n
       real(wp), intent(out) :: md
       TYPE( NLLS_control_type ), INTENT( IN ) :: options
       type( evaluate_model_work ) :: w
       
       !Jd = J*d
       call mult_J(J,n,m,d,w%Jd)
       
       ! First, get the base 
       ! 0.5 (f^T f + f^T J d + d^T' J ^T J d )
       md = 0.5 * norm2(f + w%Jd)**2
       select case (options%model)
       case (1) ! first-order (no Hessian)
          ! nothing to do here...
          continue
       case (3) ! barely second-order (identity Hessian)
          ! H = J^T J + I
          md = md + 0.5 * dot_product(d,d)
       case default
          ! these have a dynamic H -- recalculate
          ! H = J^T J + HF, HF is (an approx?) to the Hessian
          call mult_J(hf,n,n,d,w%Hd)
          md = md + 0.5 * dot_product(d,w%Hd)
       end select

     end subroutine evaluate_model
     
         
     subroutine mult_J(J,n,m,x,Jx)
       real(wp), intent(in) :: J(*), x(*)
       integer, intent(in) :: n,m
       real(wp), intent(out) :: Jx(*)
       
       real(wp) :: alpha, beta

       Jx(1:m) = 1.0
       alpha = 1.0
       beta  = 0.0

       call dgemv('N',m,n,alpha,J,m,x,1,beta,Jx,1)
       
     end subroutine mult_J

     subroutine mult_Jt(J,n,m,x,Jtx)
       double precision, intent(in) :: J(*), x(*)
       integer, intent(in) :: n,m
       double precision, intent(out) :: Jtx(*)
       
       double precision :: alpha, beta

       Jtx(1:n) = one
       alpha = one
       beta  = zero

       call dgemv('T',m,n,alpha,J,m,x,1,beta,Jtx,1)

      end subroutine mult_Jt

      subroutine solve_spd(A,b,LtL,x,n,info)
        REAL(wp), intent(in) :: A(:,:)
        REAL(wp), intent(in) :: b(:)
        REAL(wp), intent(out) :: LtL(:,:)
        REAL(wp), intent(out) :: x(:)
        integer, intent(in) :: n
        integer, intent(out) :: info
!        type( solve_spd_work ) :: w

        ! A wrapper for the lapack subroutine dposv.f
        ! get workspace for the factors....
        info = 0
        LtL(1:n,1:n) = A(1:n,1:n)
        x(1:n) = b(1:n)
        call dposv('L', n, 1, LtL, n, x, n, info)
           
      end subroutine solve_spd

      subroutine solve_general(A,b,x,n,info,w)
        REAL(wp), intent(in) :: A(:,:)
        REAL(wp), intent(in) :: b(:)
        REAL(wp), intent(out) :: x(:)
        integer, intent(in) :: n
        integer, intent(out) :: info
        type( solve_general_work ) :: w
        
        ! A wrapper for the lapack subroutine dposv.f
        ! NOTE: A would be destroyed
        w%A(1:n,1:n) = A(1:n,1:n)
        x(1:n) = b(1:n)
        call dgesv( n, 1, w%A, n, w%ipiv, x, n, info)
        
      end subroutine solve_general

      subroutine matrix_norm(x,A,norm_A_x)
        REAL(wp), intent(in) :: A(:,:), x(:)
        REAL(wp), intent(out) :: norm_A_x

        ! Calculates norm_A_x = ||x||_A = sqrt(x'*A*x)

        norm_A_x = sqrt(dot_product(x,matmul(A,x)))

      end subroutine matrix_norm

      subroutine matmult_inner(J,n,m,A)
        
        integer, intent(in) :: n,m 
        real(wp), intent(in) :: J(*)
        real(wp), intent(out) :: A(n,n)
        integer :: lengthJ
        
        ! Takes an m x n matrix J and forms the 
        ! n x n matrix A given by
        ! A = J' * J
        
        lengthJ = n*m
        
        call dgemm('T','N',n, n, m, one,&
                   J, m, J, m, & 
                   zero, A, n)
        
        
      end subroutine matmult_inner

       subroutine matmult_outer(J,n,m,A)
        
        integer, intent(in) :: n,m 
        real(wp), intent(in) :: J(*)
        real(wp), intent(out) :: A(m,m)
        integer :: lengthJ

        ! Takes an m x n matrix J and forms the 
        ! m x m matrix A given by
        ! A = J * J'
        
        lengthJ = n*m
        
        call dgemm('N','T',m, m, n, one,&
                   J, m, J, m, & 
                   zero, A, m)
        
        
      end subroutine matmult_outer
      
      subroutine outer_product(x,n,xtx)
        
        real(wp), intent(in) :: x(:)
        integer, intent(in) :: n
        real(wp), intent(out) :: xtx(:,:)

        ! Takes an n vector x and forms the 
        ! n x n matrix xtx given by
        ! xtx = x * x'

        xtx(1:n,1:n) = zero
        call dger(n, n, one, x, 1, x, 1, xtx, n)
        
      end subroutine outer_product

      subroutine min_eig_symm(A,n,ew,ev,options,info,w)
        ! calculate the leftmost eigenvalue of A
        
        real(wp), intent(in) :: A(:,:)
        integer, intent(in) :: n
        real(wp), intent(out) :: ew, ev(:)
        integer, intent(out) :: info
        type( NLLS_control_type ), INTENT( IN ) :: options
        type( min_eig_symm_work ) :: w

        real(wp) :: tol, dlamch
        integer :: lwork, i, eigsout, minindex(1)
!        real(wp), allocatable :: temp_ev(:,:), temp_ew(:)

        tol = 2*dlamch('S')!1e-15
        
        info = 0
        w%A(1:n,1:n) = A(1:n,1:n) ! copy A, as workspace for dsyev(x)
        ! note that dsyevx (but not dsyev) only destroys the lower (or upper) part of A
        ! so we could possibly reduce memory use here...leaving for 
        ! ease of understanding for now.

        lwork = size(w%work)
        if ( options%subproblem_eig_fact ) then
           ! call dsyev --> all eigs of a symmetric matrix
           call dsyev('V', & ! both ew's and ev's 
                'U', & ! upper triangle of A
                n, w%A, n, & ! data about A
                w%ew, w%work, lwork, & 
                info)
           
           minindex = minloc(w%ew)
           ew = w%ew(minindex(1))
           ev = w%A(1:n,minindex(1))
           
        else
           ! call dsyevx --> selected eigs of a symmetric matrix
           call dsyevx( 'V',& ! get both ew's and ev's
                'I',& ! just the numbered eigenvalues
                'U',& ! upper triangle of A
                n, w%A, n, & 
                1.0, 1.0, & ! not used for RANGE = 'I'
                1, 1, & ! only find the first eigenpair
                tol, & ! abstol for the eigensolver
                eigsout, & ! total number of eigs found
                ew, ev, & ! the eigenvalue and eigenvector
                n, & ! ldz (the eigenvector array)
                w%work, lwork, w%iwork, &  ! workspace
                w%ifail, & ! array containing indicies of non-converging ews
                info)

        end if
           
        ! let the calling subroutine handle the errors
        
        return
                      
      end subroutine min_eig_symm

      subroutine max_eig(A,B,n,ew,ev,info,nullevs,w)
        
        real(wp), intent(inout) :: A(:,:), B(:,:)
        integer, intent(in) :: n 
        real(wp), intent(out) :: ew, ev(:)
        integer, intent(out) :: info
        real(wp), intent(out), allocatable :: nullevs(:,:)
        type( max_eig_work ) :: w
        
        integer :: lwork, maxindex(1), no_null, halfn
        real(wp):: tau
        integer :: i 

        ! Find the max eigenvalue/vector of the generalized eigenproblem
        !     A * y = lam * B * y
        ! further, if ||y(1:n/2)|| \approx 0, find and return the 
        ! eigenvectors y(n/2+1:n) associated with this

        info = 0
        ! check that n is even (important for hard case -- see below)
        if (modulo(n,2).ne.0) then
           write(*,*) 'error : non-even sized matrix sent to max eig'
           info = 2
           return
        end if
        halfn = n/2
        lwork = size(w%work)
        call dggev('N', & ! No left eigenvectors
                   'V', &! Yes right eigenvectors
                   n, A, n, B, n, &
                   w%alphaR, w%alphaI, w%beta, & ! eigenvalue data
                   w%vr, n, & ! not referenced
                   w%vr, n, & ! right eigenvectors
                   w%work, lwork, info)

        ! now find the rightmost real eigenvalue
        w%vecisreal = .true.
        where ( abs(w%alphaI) > 1e-8 ) w%vecisreal = .false.
        
        w%ew_array(:) = w%alphaR(:)/w%beta(:)
        maxindex = maxloc(w%ew_array,w%vecisreal)


        if (maxindex(1) == 0) then
           write(*,*) 'Error, all eigs are imaginary'
           info = 1 ! Eigs imaginary error
           return
        end if
        
        tau = 1e-4 ! todo -- pass this through from above...
        ! note n/2 always even -- validated by test on entry
        if (norm2( w%vr(1:halfn,maxindex(1)) ) < tau) then 
           ! hard case
           ! let's find which ev's are null...
           w%nullindex = 0
           no_null = 0
           do i = 1,n
              if (norm2( w%vr(1:halfn,i)) < 1e-4 ) then
                 no_null = no_null + 1 
                 w%nullindex(no_null) = i
              end if
           end do
           allocate(nullevs(halfn,no_null))
           nullevs(:,:) = w%vr(halfn+1 : n,w%nullindex(1:no_null))
        end if
        
        ew = w%alphaR(maxindex(1))/w%beta(maxindex(1))
        ev(:) = w%vr(:,maxindex(1))
                
      end subroutine max_eig

      subroutine shift_matrix(A,sigma,AplusSigma,n)
        
        real(wp), intent(in)  :: A(:,:), sigma
        real(wp), intent(out) :: AplusSigma(:,:)
        integer, intent(in) :: n 

        integer :: i 
        ! calculate AplusSigma = A + sigma * I

        AplusSigma(:,:) = A(:,:)
        do i = 1,n
           AplusSigma(i,i) = AplusSigma(i,i) + sigma
        end do
                
      end subroutine shift_matrix


      
      subroutine setup_workspaces(workspace,n,m,options,info)
        
        type( NLLS_workspace ), intent(out) :: workspace
        type( NLLS_control_type ), intent(in) :: options
        integer, intent(in) :: n,m
        integer, intent(out) :: info

        integer :: lwork, lapack_info
        real(wp), allocatable :: workquery(:)
        
        info = 0      
        
        select case (options%nlls_method)
        
        case (1) ! use the dogleg method
           call setup_workspace_dogleg(n,m,workspace%calculate_step_ws%dogleg_ws, & 
                options, info)
           if (info > 0) goto 9000

        case(2) ! use the AINT method
           call setup_workspace_AINT_tr(n,m,workspace%calculate_step_ws%AINT_tr_ws, & 
                options, info)
           if (info > 0) goto 9000
           
        case(3) ! More-Sorensen 
           call setup_workspace_more_sorensen(n,m,&
                workspace%calculate_step_ws%more_sorensen_ws,options,info)
           if (info > 0) goto 9000

        end select

! evaluate model in the main routine...       
        call setup_workspace_evaluate_model(n,m,workspace%evaluate_model_ws,options,info)
        if (info > 0) goto 9000

        return

! Error statements
9000    continue 

        return
        
      end subroutine setup_workspaces

      subroutine setup_workspace_dogleg(n,m,w,options,info)
        integer, intent(in) :: n, m 
        type( dogleg_work ), intent(out) :: w
        type( NLLS_control_type ) :: options
        integer, intent(inout) :: info

        allocate(w%d_sd(n),stat = info)
        if (info > 0) goto 9000
        allocate(w%d_gn(n),stat = info)
        if (info > 0) goto 9000           
        allocate(w%ghat(n),stat = info)
        if (info > 0) goto 9000
        allocate(w%Jg(m),stat = info)
        if (info > 0) goto 9000
        ! setup space for 
        !   solve_LLS
        call setup_workspace_solve_LLS(n,m,w%solve_LLS_ws,options,info)
        if (info > 0 ) goto 9010
        ! setup space for 
        !   evaluate_model
        call setup_workspace_evaluate_model(n,m,w%evaluate_model_ws,options,info)
        if (info > 0 ) goto 9010

        return

        ! Error statements
9000    continue
        ! Allocation errors : dogleg
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for subroutine ''dogleg'': ',&
                'not enough memory.' 
           write(options%error,'(a,i0)') 'status = ', info
 
        end if
        
        return

9010    continue
        ! Allocation errors : dogleg
        if (options%print_level >= 0) then
           write(options%error,'(a)') &
                'Called from subroutine ''dogleg'': '
        end if

        return
        
      end subroutine setup_workspace_dogleg

      subroutine setup_workspace_solve_LLS(n,m,w,options,info)
        integer, intent(in) :: n, m 
        type( solve_LLS_work ) :: w 
        type( NLLS_control_type ) :: options
        integer, intent(inout) :: info
        integer :: lwork
        
        allocate( w%temp(max(m,n)), stat = info)
        if (info > 0) goto 9000
        lwork = max(1, min(m,n) + max(min(m,n), 1)*4) 
        allocate( w%work(lwork), stat = info)
        if (info > 0) goto 9000
        allocate( w%Jlls(n*m), stat = info)
        if (info > 0) goto 9000
        
        return
        
9000    continue
        ! Allocation errors : dogleg
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for subroutine ''solve_LLS'': ',&
                'not enough memory.' 
        end if
        
        return

      end subroutine setup_workspace_solve_LLS
      
      subroutine setup_workspace_evaluate_model(n,m,w,options,info)
        integer, intent(in) :: n, m        
        type( evaluate_model_work ) :: w
        type( NLLS_control_type ) :: options
        integer, intent(out) :: info
        
        allocate( w%Jd(m), stat = info )
        if (info > 0) goto 9000
        allocate( w%Hd(n), stat = info)
        if (info > 0) goto 9000

        return

9000    continue
        ! Allocation errors : dogleg
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for subroutine ''evaluate_model'': ',&
                'not enough memory.' 
        end if
        
        return
      end subroutine setup_workspace_evaluate_model

      subroutine setup_workspace_AINT_tr(n,m,w,options,info)
        integer, intent(in) :: n, m 
        type( AINT_tr_work ) :: w
        type( NLLS_control_type ) :: options
        integer, intent(out) :: info
        
        allocate(w%A(n,n),stat = info)
        if (info > 0) goto 9000
        allocate(w%v(n),stat = info)
        if (info > 0) goto 9000
        allocate(w%B(n,n),stat = info)
        if (info > 0) goto 9000
        allocate(w%p0(n),stat = info)
        if (info > 0) goto 9000
        allocate(w%p1(n),stat = info)
        if (info > 0) goto 9000
        allocate(w%M0(2*n,2*n),stat = info)
        if (info > 0) goto 9000
        allocate(w%M1(2*n,2*n),stat = info)
        if (info > 0) goto 9000
        allocate(w%y(2*n),stat = info)
        if (info > 0) goto 9000
        allocate(w%gtg(n,n),stat = info)
        if (info > 0) goto 9000
        allocate(w%q(n),stat = info)
        if (info > 0) goto 9000
        allocate(w%LtL(n,n),stat = info)
        if (info > 0) goto 9000
        ! setup space for max_eig
        call setup_workspace_max_eig(n,m,w%max_eig_ws,options,info)
        if (info > 0) goto 9010
        call setup_workspace_evaluate_model(n,m,w%evaluate_model_ws,options,info)
        if (info > 0) goto 9010
        ! setup space for the solve routine
        if ((options%model .ne. 1).and.(options%model .ne. 3)) then
           call setup_workspace_solve_general(n,m,w%solve_general_ws,options,info)
           if (info > 0 ) goto 9010
        end if

        return
        
9000    continue
        ! Allocation errors : dogleg
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for subroutine ''AINT_tr'': ',&
                'not enough memory.' 
        end if
        
        return

9010    continue
        ! Allocation errors : dogleg
        if (options%print_level >= 0) then
           write(options%error,'(a)') &
                'Called from subroutine ''solve_LLS'': '
        end if
        return
        
      end subroutine setup_workspace_AINT_tr


      subroutine setup_workspace_min_eig_symm(n,m,w,options,info)
        integer, intent(in) :: n, m 
        type( min_eig_symm_work) :: w
        type( NLLS_control_type ) :: options
        integer, intent(out) :: info
        
        real(wp), allocatable :: workquery(:)
        integer :: lapack_info, lwork, eigsout
        
        allocate(w%A(n,n),stat = info)
        if (info > 0) goto 9000
        
        allocate(workquery(1),stat = info)
        if (info > 0) goto 9000
        lapack_info = 0
        
        if (options%subproblem_eig_fact) then 
           allocate(w%ew(n), stat = info)
           if (info > 0) goto 9000
           
           call dsyev('V', & ! both ew's and ev's 
                'U', & ! upper triangle of A
                n, w%A, n, & ! data about A
                w%ew, workquery, -1, & 
                lapack_info)
        else
           allocate( w%iwork(5*n), stat = info )
           if (info > 0) goto 9000
           allocate( w%ifail(n), stat = info ) 
           if (info > 0) goto 9000
           
           ! make a workspace query to dsyevx
           call dsyevx( 'V',& ! get both ew's and ev's
                     'I',& ! just the numbered eigenvalues
                     'U',& ! upper triangle of A
                      n, w%A, n, & 
                      1.0, 1.0, & ! not used for RANGE = 'I'
                      1, 1, & ! only find the first eigenpair
                      0.5, & ! abstol for the eigensolver
                      eigsout, & ! total number of eigs found
                      1.0, 1.0, & ! the eigenvalue and eigenvector
                      n, & ! ldz (the eigenvector array)
                      workquery, -1, w%iwork, &  ! workspace
                      w%ifail, & ! array containing indicies of non-converging ews
                      lapack_info)
           if (lapack_info > 0) goto 9020
        end if
        lwork = int(workquery(1))
        deallocate(workquery)
        allocate( w%work(lwork), stat = info )
        if (info > 0) goto 9000

        return
        
9000    continue
        ! Allocation errors : min_eig_symm
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for subroutine ''min_eig_symm'': ',&
                'not enough memory.' 
        end if
        
        return

9020    continue
        ! Error return from lapack routine
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for lapack subroutine: ',&
                'not enough memory.' 
        end if
        return

      end subroutine setup_workspace_min_eig_symm
      
      subroutine setup_workspace_max_eig(n,m,w,options,info)
        integer, intent(in) :: n, m 
        type( max_eig_work) :: w
        type( NLLS_control_type ) :: options
        integer, intent(out) :: info
        real(wp), allocatable :: workquery(:)
        integer :: lapack_info, lwork
        
        allocate( w%alphaR(2*n), stat = info)
        if (info > 0) goto 9000
        allocate( w%alphaI(2*n), stat = info)
        if (info > 0) goto 9000
        allocate( w%beta(2*n),   stat = info)
        if (info > 0) goto 9000
        allocate( w%vr(2*n,2*n), stat = info)
        if (info > 0) goto 9000
        allocate( w%ew_array(2*n), stat = info)
        if (info > 0) goto 9000
        allocate(workquery(1),stat = info)
        if (info > 0) goto 9000
        ! make a workspace query to dggev
        call dggev('N', & ! No left eigenvectors
             'V', &! Yes right eigenvectors
             2*n, 1.0, 2*n, 1.0, 2*n, &
             1.0, 0.1, 0.1, & ! eigenvalue data
             0.1, 2*n, & ! not referenced
             0.1, 2*n, & ! right eigenvectors
             workquery, -1, lapack_info)
        if (lapack_info > 0) goto 9020
        lwork = int(workquery(1))
        deallocate(workquery)
        allocate( w%work(lwork), stat = info)
        if (info > 0) goto 9000
        allocate( w%nullindex(2*n), stat = info)
        if (info > 0) goto 9000
        allocate( w%vecisreal(2*n), stat = info)
        if (info > 0) goto 9000

        return
        
9000    continue
        ! Allocation errors : dogleg
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for subroutine ''AINT_tr'': ',&
                'not enough memory.' 
        end if
        
        return

9020    continue
        ! Error return from lapack routine
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for lapack subroutine: ',&
                'not enough memory.' 
        end if
        return

      end subroutine setup_workspace_max_eig


      subroutine setup_workspace_solve_general(n, m, w, options, info)
        integer, intent(in) :: n, m 
        type( solve_general_work ) :: w
        type( NLLS_control_type ) :: options
        integer, intent(out) :: info
        
        allocate( w%A(n,n), stat = info)
        if (info > 0) goto 9000
        allocate( w%ipiv(n), stat = info)
        if (info > 0) goto 9000
        
        return
        
9000    continue
        ! Allocation errors : dogleg
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for subroutine ''solve_general'': ',&
                'not enough memory.' 
        end if
        
        return

      end subroutine setup_workspace_solve_general

      subroutine setup_workspace_more_sorensen(n,m,w,options,info)
        integer, intent(in) :: n,m
        type( more_sorensen_work ) :: w
        type( NLLS_control_type ) :: options
        integer, intent(out) :: info
        allocate(w%A(n,n),stat = info)
        if (info > 0) goto 9000
        allocate(w%LtL(n,n),stat = info)
        if (info > 0) goto 9000
        allocate(w%v(n),stat = info)
        if (info > 0) goto 9000
        allocate(w%q(n),stat = info)
        if (info > 0) goto 9000
        allocate(w%y1(n),stat = info)
        if (info > 0) goto 9000
        allocate(w%AplusSigma(n,n),stat = info)
        if (info > 0) goto 9000

        call setup_workspace_min_eig_symm(n,m,w%min_eig_symm_ws,options,info)
        if (info > 0) goto 9010
        
        return
        
9000    continue
        ! Allocation errors : dogleg
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for subroutine ''more_sorensen'': ',&
                'not enough memory.' 
        end if
        
        return
        
9010    continue
        ! Allocation errors : dogleg
        if (options%print_level >= 0) then
           write(options%error,'(a)') &
                'Called from subroutine ''dogleg'': '
        end if

        return


      end subroutine setup_workspace_more_sorensen
      

end module nlls_module


