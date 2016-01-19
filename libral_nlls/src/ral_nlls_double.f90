! ral_nlls_double :: a nonlinear least squares solver

module ral_nlls_double

  use RAL_NLLS_DTRS_double

  implicit none

  private

  integer, parameter :: wp = kind(1.0d0)
  integer, parameter :: long = selected_int_kind(8)
  real (kind = wp), parameter :: tenm3 = 1.0e-3
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

  
  TYPE, PUBLIC :: NLLS_options
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! P R I N T I N G   C O N T R O L S !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
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

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! M A I N   R O U T I N E   C O N T R O L S !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

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
!      1  Gauss-Newton (no 2nd derivatives)
!      2  second-order (exact Hessian)
!      3  barely second-order (identity Hessian)
!      4  secant second-order (sparsity-based)
!      5  secant second-order (limited-memory BFGS, with %lbfgs_vectors history)
!      6  secant second-order (limited-memory SR1, with %lbfgs_vectors history)
!      7  hybrid (Gauss-Newton until gradient small, then Newton)
!      8  hybrid (Newton first, then Gauss-Newton)
!      9  hybrid (using Madsen, Nielsen and Tingleff's method)    
 
     INTEGER :: model = 9

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
!
!$$     INTEGER :: norm = 1


     INTEGER :: nlls_method = 4

!   specify the method used to solve the trust-region sub problem
!      1 Powell's dogleg
!      2 AINT method (of Yuji Nat.)
!      3 More-Sorensen
!      4 Galahad's DTRS
!      ...

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
     
!   should we scale the initial trust region radius?
     
     integer :: relative_tr_radius = 0

!   if relative_tr_radius == 1, then pick a scaling parameter
!   Madsen, Nielsen and Tingleff say pick this to be 1e-6, say, if x_0 is good,
!   otherwise 1e-3 or even 1 would be good starts...
     
     real (kind = wp) :: initial_radius_scale = 1.0!tenm3

!   if relative_tr_radius /= 1, then set the 
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

!   if model=7, then the value with which we switch on second derivatives
     
     real ( kind = wp ) :: hybrid_switch = 0.1_wp

!   the maximum CPU time allowed (-ve means infinite)
     
!$$     REAL ( KIND = wp ) :: cpu_time_limit = - one

!   the maximum elapsed clock time allowed (-ve means infinite)

!$$     REAL ( KIND = wp ) :: clock_time_limit = - one
 
!   shall we use explicit second derivatives, or approximate using a secant 
!   method
     
     LOGICAL :: exact_second_derivatives = .true.
      
!   is the Hessian matrix of second derivatives available or is access only
!    via matrix-vector products?

!     LOGICAL :: hessian_available = .TRUE.

!   use a direct (factorization) or (preconditioned) iterative method to 
!    find the search direction

!$$     LOGICAL :: subproblem_direct = .FALSE.

!   use a factorization (dsyev) to find the smallest eigenvalue for the subproblem
!    solve? (alternative is an iterative method (dsyevx)
     LOGICAL :: subproblem_eig_fact = .FALSE. ! undocumented....
     

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

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! M O R E - S O R E N S E N   C O N T R O L S !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!     

    integer  :: more_sorensen_maxits = 500
    real(wp) :: more_sorensen_shift = 1e-13
    real(wp) :: more_sorensen_tiny = 10.0 * epsmch
    real(wp) :: more_sorensen_tol = 1e-3

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! H Y B R I D   C O N T R O L S !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

! what's the tolerance such that ||J^T f || < tol * 0.5 ||f||^2 triggers a switch
    real(wp) :: hybrid_tol = 0.02

! how many successive iterations does the above condition need to hold before we switch?
    integer  :: hybrid_switch_its = 3

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! O U T P U T   C O N T R O L S !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

! Shall we output progess vectors at termination of the routine?
     logical :: output_progress_vectors = .false.

  END TYPE nlls_options

!  - - - - - - - - - - - - - - - - - - - - - - - 
!   inform derived type with component defaults
!  - - - - - - - - - - - - - - - - - - - - - - - 

  TYPE, PUBLIC :: nlls_inform
     
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

!  test on the size of f satisfied?
     
     integer :: convergence_normf = 0

!  test on the size of the gradient satisfied?
     
     integer :: convergence_normg = 0
     
!  vector of residuals 
     
     real(wp), allocatable :: resvec(:)

!  vector of gradients 
     
     real(wp), allocatable :: gradvec(:)

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

  END TYPE nlls_inform

  type, public :: params_base_type
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
    
    type, private :: all_eig_symm_work ! workspace for subroutine all_eig_symm
       real(wp), allocatable :: work(:)
    end type all_eig_symm_work
        
    type, private :: solve_dtrs_work ! workspace for subroutine dtrs_work
       real(wp), allocatable :: A(:,:), ev(:,:), ew(:), v(:), v_trans(:), d_trans(:)
       type( all_eig_symm_work ) :: all_eig_symm_ws
    end type solve_dtrs_work
        
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
       type( solve_dtrs_work ) :: solve_dtrs_ws
    end type calculate_step_work

    type, public :: NLLS_workspace ! all workspaces called from the top level
       integer :: first_call = 1
       integer :: iter = 0 
       real(wp) :: normF0, normJF0, normF
       real(wp) :: normJFold, normJF_Newton
       real(wp) :: Delta
       logical :: use_second_derivatives = .false.
       integer :: hybrid_count = 0
       real(wp) :: hybrid_tol = 1.0
       real(wp), allocatable :: fNewton(:), JNewton(:), XNewton(:)
       real(wp), allocatable :: J(:)
       real(wp), allocatable :: f(:), fnew(:)
       real(wp), allocatable :: hf(:)
       real(wp), allocatable :: d(:), g(:), Xnew(:)
       real(wp), allocatable :: y(:), y_sharp(:), g_old(:), g_mixed(:)
       real(wp), allocatable :: resvec(:), gradvec(:)
       type ( calculate_step_work ) :: calculate_step_ws
       type ( evaluate_model_work ) :: evaluate_model_ws
    end type NLLS_workspace

    public :: nlls_solve, nlls_iterate, remove_workspaces
    
    public :: setup_workspaces, solve_dtrs, findbeta, mult_j
    public :: mult_jt, solve_spd, solve_general, matmult_inner
    public :: matmult_outer, outer_product, min_eig_symm, max_eig

contains


  SUBROUTINE NLLS_SOLVE( n, m, X,                   & 
                         eval_F, eval_J, eval_HF,   & 
                         params,                    &
                         options, inform )
    
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
    TYPE( NLLS_inform ), INTENT( OUT ) :: inform
    TYPE( NLLS_options ), INTENT( IN ) :: options
    procedure( eval_f_type ) :: eval_F
    procedure( eval_j_type ) :: eval_J
    procedure( eval_hf_type ) :: eval_HF
    class( params_base_type ) :: params
      
    integer  :: i
    
    type ( NLLS_workspace ) :: w
    
!!$    write(*,*) 'Controls in:'
!!$    write(*,*) control
!!$    write(*,*) 'error = ',options%error
!!$    write(*,*) 'out = ', options%out
!!$    write(*,*) 'print_level = ', options%print_level
!!$    write(*,*) 'maxit = ', options%maxit
!!$    write(*,*) 'model = ', options%model
!!$    write(*,*) 'nlls_method = ', options%nlls_method
!!$    write(*,*) 'lls_solver = ', options%lls_solver
!!$    write(*,*) 'stop_g_absolute = ', options%stop_g_absolute
!!$    write(*,*) 'stop_g_relative = ', options%stop_g_relative     
!!$    write(*,*) 'initial_radius = ', options%initial_radius
!!$    write(*,*) 'maximum_radius = ', options%maximum_radius
!!$    write(*,*) 'eta_successful = ', options%eta_successful
!!$    write(*,*) 'eta_very_successful = ',options%eta_very_successful
!!$    write(*,*) 'eta_too_successful = ',options%eta_too_successful
!!$    write(*,*) 'radius_increase = ',options%radius_increase
!!$    write(*,*) 'radius_reduce = ',options%radius_reduce
!!$    write(*,*) 'radius_reduce_max = ',options%radius_reduce_max
!!$    write(*,*) 'hybrid_switch = ',options%hybrid_switch
!!$    write(*,*) 'subproblem_eig_fact = ',options%subproblem_eig_fact
!!$    write(*,*) 'more_sorensen_maxits = ',options%more_sorensen_maxits
!!$    write(*,*) 'more_sorensen_shift = ',options%more_sorensen_shift
!!$    write(*,*) 'more_sorensen_tiny = ',options%more_sorensen_tiny
!!$    write(*,*) 'more_sorensen_tol = ',options%more_sorensen_tol
!!$    write(*,*) 'hybrid_tol = ', options%hybrid_tol
!!$    write(*,*) 'hybrid_switch_its = ', options%hybrid_switch_its
!!$    write(*,*) 'output_progress_vectors = ',options%output_progress_vectors

    main_loop: do i = 1,options%maxit
       
       call nlls_iterate(n, m, X,                   & 
                         w, &
                         eval_F, eval_J, eval_HF,   & 
                         params,                    &
                         inform, options)
       ! test the returns to see if we've converged
       if (inform%status .ne. 0) then 
          return 
       elseif ((inform%convergence_normf == 1).or.(inform%convergence_normg == 1)) then
          return
       end if
       
     end do main_loop
    
     ! If we reach here, then we're over maxits     
     if (options%print_level > 0 ) write(options%out,1040) 
     inform%status = -1
    
     RETURN

! Non-executable statements

! print level > 0

1040 FORMAT(/,'RAL_NLLS failed to converge in the allowed number of iterations')

!  End of subroutine RAL_NLLS

   END SUBROUTINE NLLS_SOLVE
  
  subroutine nlls_iterate(n, m, X,                   & 
                          w,                         & 
                          eval_F, eval_J, eval_HF,   & 
                          params,                    &
                          inform, options)

    INTEGER, INTENT( IN ) :: n, m
    REAL( wp ), DIMENSION( n ), INTENT( INOUT ) :: X
    TYPE( nlls_inform ), INTENT( OUT ) :: inform
    TYPE( nlls_options ), INTENT( IN ) :: options
    type( NLLS_workspace ), INTENT( INOUT ) :: w
    procedure( eval_f_type ) :: eval_F
    procedure( eval_j_type ) :: eval_J
    procedure( eval_hf_type ) :: eval_HF
    class( params_base_type ) :: params
      
    integer :: jstatus=0, fstatus=0, hfstatus=0, astatus = 0, svdstatus = 0
    integer :: i, no_reductions, max_tr_decrease = 100
    real(wp) :: rho, normJF, normFnew, md, Jmax, JtJdiag
    real(wp) :: FunctionValue, hybrid_tol
    logical :: success, calculate_svd_J
    real(wp) :: s1, sn
    
    ! todo: make max_tr_decrease a control variable

    ! Perform a single iteration of the RAL_NLLS loop
    
    calculate_svd_J = .true. ! todo :: make a control variable 

    if (w%first_call == 1) then
       ! This is the first call...allocate arrays, and get initial 
       ! function evaluations
       if ( options%print_level >= 3 )  write( options%out , 3000 ) 
       ! first, check if n < m
       if (n > m) goto 4070

       call setup_workspaces(w,n,m,options,inform%alloc_status)
       if ( inform%alloc_status > 0) goto 4000

       call eval_F(fstatus, n, m, X, w%f, params)
       inform%f_eval = inform%f_eval + 1
       if (fstatus > 0) goto 4020
       call eval_J(jstatus, n, m, X, w%J, params)
       inform%g_eval = inform%g_eval + 1
       if (jstatus > 0) goto 4010

       if (options%relative_tr_radius == 1) then 
          ! first, let's get diag(J^TJ)
          Jmax = 0.0
          do i = 1, n
             ! note:: assumes column-storage of J
             JtJdiag = norm2( w%J( (i-1)*m + 1 : i*m ) )
             if (JtJdiag > Jmax) Jmax = JtJdiag
          end do
          w%Delta = options%initial_radius_scale * (Jmax**2)
          if (options%print_level .ge. 3) write(options%out,3110) w%Delta
       else
          w%Delta = options%initial_radius
       end if
              
       if ( calculate_svd_J ) then
          call get_svd_J(n,m,w%J,s1,sn,options,svdstatus)
          if ((svdstatus .ne. 0).and.(options%print_level .ge. 3)) then 
             write( options%out, 3000 ) svdstatus
          end if
       end if

       w%normF = norm2(w%f)
       w%normF0 = w%normF

       !    g = -J^Tf
       call mult_Jt(w%J,n,m,w%f,w%g)
       w%g = -w%g
       normJF = norm2(w%g)
       w%normJF0 = normJF
       if (options%model == 8 .or. options%model == 9) w%normJFold = normJF

       if (options%model == 9) then
          ! make this relative....
          w%hybrid_tol = options%hybrid_tol * ( normJF/(0.5*(w%normF**2)) )
       end if
       
       ! save some data 
       inform%obj = 0.5 * ( w%normF**2 )
       inform%norm_g = normJF

       if (options%output_progress_vectors) then
          w%resvec(1) = inform%obj
          w%gradvec(1) = inform%norm_g
       end if
       
       select case (options%model)
       case (1) ! first-order
          w%hf(1:n**2) = zero
       case (2) ! second order
          if ( options%exact_second_derivatives ) then
             call eval_HF(hfstatus, n, m, X, w%f, w%hf, params)
             inform%h_eval = inform%h_eval + 1
             if (hfstatus > 0) goto 4030
          else
             ! S_0 = 0 (see Dennis, Gay and Welsch)
             w%hf(1:n**2) = zero
          end if
       case (3) ! barely second order (identity hessian)
          w%hf(1:n**2) = zero
          w%hf((/ ( (i-1)*n + i, i = 1,n ) /)) = one
       case (7) ! hybrid
          ! first call, so always first-derivatives only
          w%hf(1:n**2) = zero
       case (8) ! hybrid II
          ! always second order for first call...
          if ( options%exact_second_derivatives ) then
             call eval_HF(hfstatus, n, m, X, w%f, w%hf, params)
             inform%h_eval = inform%h_eval + 1
             if (hfstatus > 0) goto 4030
          else
             ! S_0 = 0 (see Dennis, Gay and Welsch)
             w%hf(1:n**2) = zero
          end if
          w%use_second_derivatives = .true.
       case (9) ! hybrid (MNT)
          ! use first-order method initially
          w%hf(1:n**2) = zero
          w%use_second_derivatives = .false.
       case default
          goto 4040 ! unsupported model -- return to user
       end select
       
       
    end if


    w%iter = w%iter + 1
    if ( options%print_level >= 3 )  write( options%out , 3030 ) w%iter
    inform%iter = w%iter
    
    rho  = -one ! intialize rho as a negative value
    success = .false.
    no_reductions = 0

    do while (.not. success) ! loop until successful
       no_reductions = no_reductions + 1
       if (no_reductions > max_tr_decrease+1) goto 4050

       !+++++++++++++++++++++++++++++++++++++++++++!
       ! Calculate the step                        !
       !    d                                      !   
       ! that the model thinks we should take next !
       !+++++++++++++++++++++++++++++++++++++++++++!
       call calculate_step(w%J,w%f,w%hf,w%g,n,m,w%Delta,w%d,options,inform,& 
            w%calculate_step_ws)
       if (inform%status .ne. 0) goto 4000
       
       !++++++++++++++++++!
       ! Accept the step? !
       !++++++++++++++++++!
       w%Xnew = X + w%d
       call eval_F(fstatus, n, m, w%Xnew, w%fnew, params)
       inform%f_eval = inform%f_eval + 1
       if (fstatus > 0) goto 4020
       normFnew = norm2(w%fnew)
       
       !++++++++++++++++++++++++++++!
       ! Get the value of the model !
       !      md :=   m_k(d)        !
       ! evaluated at the new step  !
       !++++++++++++++++++++++++++++!
       call evaluate_model(w%f,w%J,w%hf,w%d,md,m,n,options,w%evaluate_model_ws)
       
       !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
       ! Calculate the quantity                                   ! 
       !   rho = 0.5||f||^2 - 0.5||fnew||^2 =   actual_reduction  !
       !         --------------------------   ------------------- !
       !             m_k(0)  - m_k(d)         predicted_reduction !
       !                                                          !
       ! if model is good, rho should be close to one             !
       !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
       call calculate_rho(w%normF,normFnew,md,rho)
       if (rho > options%eta_successful) success = .true.
       
       !++++++++++++++++++++++!
       ! Update the TR radius !
       !++++++++++++++++++++++!
       call update_trust_region_radius(rho,options,w%Delta)
       
       !+++++++++++++++++++++++!
       ! Add tests for model=8 !
       !+++++++++++++++++++++++!
       model8_success: if ( success .and. (options%model == 8) ) then

          if (.not. options%exact_second_derivatives) then 
             ! first, let's save some old values...
             w%g_old = w%g
             ! g_mixed = J_k^T r_{k+1}
             call mult_Jt(w%J,n,m,w%fnew,w%g_mixed)
          end if

          ! evaluate J and hf at the new point
          call eval_J(jstatus, n, m, w%Xnew, w%J, params)
          inform%g_eval = inform%g_eval + 1
          if (jstatus > 0) goto 4010
          if ( calculate_svd_J ) then
             call get_svd_J(n,m,w%J,s1,sn,options,svdstatus)
             if ((svdstatus .ne. 0).and.(options%print_level > 3)) then 
                write( options%out, 3000 ) svdstatus
             end if
          end if
          

          ! g = -J^Tf
          call mult_Jt(w%J,n,m,w%fnew,w%g)
          w%g = -w%g
       
          w%normF = normFnew
          normJF = norm2(w%g)
          
          decrease_grad: if (normJF > w%normJFold) then
             ! no reduction in residual...
             which_time_round: if (w%use_second_derivatives) then
                w%use_second_derivatives = .false.
                w%hf(1:n**2) = zero
                w%normJF_Newton = normJF
                success = .false.
                ! copy current vectors....
                ! (maybe streamline for production?!)
                w%fNewton(:) = w%fnew(:)
                w%JNewton(:) = w%J(:)
                w%XNewton(:) = w%Xnew(:)
             else  
                ! Gauss-Newton gave no benefit either....
                w%use_second_derivatives = .true.
                Newton_better: if ( w%normJF_Newton < normJF ) then
                   ! Newton values were better...replace
                   w%fnew(:) = w%fNewton(:)
                   w%J(:) = w%JNewton(:)
                   w%Xnew(:) = w%XNewton(:)
                   w%normJFold = w%normJF_Newton
                   normJF = w%normJF_Newton
                else
                   w%normJFold = normJF
                end if Newton_better
                success = .true.
             end if which_time_round
          else 
             w%normJFold = normJF
          end if decrease_grad
                 
       end if model8_success

       if (.not. success) then
          ! finally, check d makes progress
          if ( norm2(w%d) < epsmch * norm2(w%Xnew) ) goto 4060
       end if
    end do
    ! if we reach here, a successful step has been found
    
    ! update X and f
    X(:) = w%Xnew(:)
    w%f(:) = w%fnew(:)
    
    if ( options%model .ne. 8 ) then 
       
       if (.not. options%exact_second_derivatives) then 
          ! first, let's save some old values...
          ! g_old = -J_k^T r_k
          w%g_old = w%g
          ! g_mixed = -J_k^T r_{k+1}
          call mult_Jt(w%J,n,m,w%fnew,w%g_mixed)
          w%g_mixed = -w%g_mixed
       end if

       ! evaluate J and hf at the new point
       call eval_J(jstatus, n, m, X, w%J, params)
       inform%g_eval = inform%g_eval + 1
       if (jstatus > 0) goto 4010
       if ( calculate_svd_J ) then
          call get_svd_J(n,m,w%J,s1,sn,options,svdstatus)
          if ((svdstatus .ne. 0).and.(options%print_level > 3)) then 
             write( options%out, 3000 ) svdstatus
          end if
       end if
       
       ! g = -J^Tf
       call mult_Jt(w%J,n,m,w%f,w%g)
       w%g = -w%g

       if ( options%model == 9) w%normJFold = normJF

       w%normF = normFnew
       normJF = norm2(w%g)
       
    end if

    ! setup the vectors needed if second derivatives are not available
    if (.not. options%exact_second_derivatives) then 
       
       w%y       = w%g_old   - w%g
       w%y_sharp = w%g_mixed - w%g

    end if

    select case (options%model) ! only update hessians than change..
    case (1) ! first-order
       continue
    case (2) ! second order
       call apply_second_order_info(hfstatus,n,m, & 
            X,w%f,w%hf,eval_Hf, &
            w%d, w%y, w%y_sharp,  &
            params,options,inform)
!       call eval_HF(hfstatus, n, m, X, w%f, w%hf, params)
!       inform%h_eval = inform%h_eval + 1
       if (hfstatus > 0) goto 4030
    case (3) ! barely second order (identity hessian)
       continue
    case (7) ! hybrid method
       if ( w%use_second_derivatives ) then 
          ! hybrid switch turned on....
          
          call apply_second_order_info(hfstatus,n,m, &
               X,w%f,w%hf,eval_Hf, &
               w%d, w%y, w%y_sharp,  &
               params,options,inform)
!          call eval_HF(hfstatus, n, m, X, w%f, w%hf, params)
!          inform%h_eval = inform%h_eval + 1
          if (hfstatus > 0) goto 4030
       end if
    case (8)       
       call apply_second_order_info(hfstatus,n,m,&
            X,w%f,w%hf,eval_Hf, &
            w%d, w%y, w%y_sharp,  &
            params,options,inform)
!       call eval_HF(hfstatus, n, m, X, w%f, w%hf, params)
!       inform%h_eval = inform%h_eval + 1
       if (hfstatus > 0) goto 4030
    case (9)
       ! First, check if we need to switch methods
       if (w%use_second_derivatives) then 
          if (normJf > w%normJFold) then 
             ! switch to Gauss-Newton             
             if (options%print_level .ge. 3) write(options%out,3120) 
             w%use_second_derivatives = .false.
          end if
       else
          FunctionValue = 0.5 * (w%normF**2)
          if ( normJf/FunctionValue < w%hybrid_tol ) then 
             w%hybrid_count = w%hybrid_count + 1
             if (w%hybrid_count == options%hybrid_switch_its) then
                ! use (Quasi-)Newton
                if (options%print_level .ge. 3) write(options%out,3130) 
                w%use_second_derivatives = .true.
                w%hybrid_count = 0
             end if
          else 
             w%hybrid_count = 0
          end if
       end if

       if (w%use_second_derivatives) then 
          call apply_second_order_info(hfstatus,n,m, &
               X,w%f,w%hf,eval_Hf, &
               w%d, w%y, w%y_sharp,  &
               params,options,inform)
!          call eval_HF(hfstatus, n, m, X, w%f, w%hf, params)
 !         inform%h_eval = inform%h_eval + 1
          if (hfstatus > 0) goto 4030
       else 
          w%hf(1:n**2) = zero
       end if
    end select

    ! update the stats 
    inform%obj = 0.5*(w%normF**2)
    inform%norm_g = normJF
    if (options%output_progress_vectors) then
       w%resvec (w%iter + 1) = inform%obj
       w%gradvec(w%iter + 1) = inform%norm_g
    end if
    
    if ( (options%model == 7) .and. (normJF < options%hybrid_switch) ) then
       w%use_second_derivatives = .true.
    end if
    
    if (options%print_level >=3) write(options%out,3010) inform%obj
    if (options%print_level >=3) write(options%out,3060) normJF/w%normF

    !++++++++++++++++++!
    ! Test convergence !
    !++++++++++++++++++!
    call test_convergence(w%normF,normJF,w%normF0,w%normJF0,options,inform)
    if (inform%convergence_normf == 1) goto 5000 ! <----converged!!
    if (inform%convergence_normg == 1) goto 5010 ! <----converged!!

    if (options%print_level > 2 ) write(options%out,3100) rho

! Non-executable statements

! print level > 0

!1040 FORMAT(/,'RAL_NLLS failed to converge in the allowed number of iterations')

! print level > 1

! print level > 2
3000 FORMAT(/,'* Running RAL_NLLS *')
3010 FORMAT('0.5 ||f||^2 = ',ES12.4)
3030 FORMAT('== Starting iteration ',i0,' ==')
3060 FORMAT('||J''f||/||f|| = ',ES12.4)

!3090 FORMAT('Step was unsuccessful -- rho =', ES12.4)
3100 FORMAT('Step was successful -- rho =', ES12.4)
3110 FORMAT('Initial trust region radius taken as ', ES12.4)
3120 FORMAT('** Switching to Gauss-Newton **')
3130 FORMAT('** Switching to (Quasi-)Newton **')
! error returns
4000 continue
    ! generic end of algorithm
        ! all (final) exits should pass through here...
    if (options%output_progress_vectors) then
       if(.not. allocated(inform%resvec)) then 
          allocate(inform%resvec(w%iter + 1), stat = astatus)
          if (astatus > 0) then
             inform%status = -9999
             return
          end if
          inform%resvec(1:w%iter + 1) = w%resvec(1:w%iter + 1)
       end if
       if(.not. allocated(inform%gradvec)) then 
          allocate(inform%gradvec(w%iter + 1), stat = astatus)
          if (astatus > 0) then
             inform%status = -9999
             return
          end if
          inform%gradvec(1:w%iter + 1) = w%gradvec(1:w%iter + 1)
       end if
    end if

    return

4010 continue
    ! Error in eval_J
    if (options%print_level > 0) then
       write(options%error,'(a,i0)') 'Error code from eval_J, status = ', jstatus
    end if
    inform%status = -2
    goto 4000

4020 continue
    ! Error in eval_J
    if (options%print_level > 0) then
       write(options%error,'(a,i0)') 'Error code from eval_F, status = ', fstatus
    end if
    inform%status = -2
    goto 4000

4030 continue
    ! Error in eval_HF
    if (options%print_level > 0) then
       write(options%error,'(a,i0)') 'Error code from eval_HF, status = ', hfstatus
    end if
    inform%status = -2
    goto 4000

4040 continue 
    ! unsupported choice of model
    if (options%print_level > 0) then
       write(options%error,'(a,i0,a)') 'Error: the choice of options%model = ', &
            options%model, ' is not supported'
    end if
    inform%status = -3
   goto 4000

4050 continue 
    ! max tr reductions exceeded
    if (options%print_level > 0) then
       write(options%error,'(a)') 'Error: maximum tr reductions reached'
    end if
    inform%status = -500
    goto 4000

4060 continue 
    ! x makes no progress
    if (options%print_level > 0) then
       write(options%error,'(a)') 'No further progress in X'
    end if
    inform%status = -700
    goto 4000

4070 continue
    ! n > m on entry
    if (options%print_level > 0) then
       write(options%error,'(a)') ''
    end if
    inform%status = -800
    goto 4000

! convergence 
5000 continue
    ! convegence test satisfied
    if (options%print_level > 2) then
       write(options%out,'(a,i0)') 'RAL_NLLS converged (on ||f|| test) at iteration ', &
            w%iter
    end if
    goto 4000

5010 continue
    if (options%print_level > 2) then
       write(options%out,'(a,i0)') 'RAL_NLLS converged (on gradient test) at iteration ', &
            w%iter
    end if
    goto 4000


!  End of subroutine RAL_NLLS_iterate

  end subroutine nlls_iterate


  subroutine ral_nlls_finalize(w,options)
    
    type( nlls_workspace ) :: w
    type( nlls_options ) :: options
    
    w%first_call = 1

    call remove_workspaces(w,options)   
    
  end subroutine ral_nlls_finalize


  SUBROUTINE calculate_step(J,f,hf,g,n,m,Delta,d,options,inform,w)

! -------------------------------------------------------
! calculate_step, find the next step in the optimization
! -------------------------------------------------------

     REAL(wp), intent(in) :: J(:), f(:), hf(:), g(:), Delta
     integer, intent(in)  :: n, m
     real(wp), intent(out) :: d(:)
     TYPE( nlls_options ), INTENT( IN ) :: options
     TYPE( nlls_inform ), INTENT( INOUT ) :: inform
     TYPE( calculate_step_work ) :: w
     select case (options%nlls_method)
        
     case (1) ! Powell's dogleg
        call dogleg(J,f,hf,g,n,m,Delta,d,options,inform,w%dogleg_ws)
     case (2) ! The AINT method
        call AINT_TR(J,f,hf,n,m,Delta,d,options,inform,w%AINT_tr_ws)
     case (3) ! More-Sorensen
        call more_sorensen(J,f,hf,n,m,Delta,d,options,inform,w%more_sorensen_ws)
     case (4) ! Galahad
        call solve_dtrs(J,f,hf,n,m,Delta,d,w%solve_dtrs_ws,options,inform)
     case default
        
        if ( options%print_level > 0 ) then
           write(options%error,'(a)') 'Error: unknown value of options%nlls_method'
           write(options%error,'(a,i0)') 'options%nlls_method = ', options%nlls_method
           inform%status = -110 ! fix me
        end if

     end select

   END SUBROUTINE calculate_step


   SUBROUTINE dogleg(J,f,hf,g,n,m,Delta,d,options,inform,w)
! -----------------------------------------
! dogleg, implement Powell's dogleg method
! -----------------------------------------

     REAL(wp), intent(in) :: J(:), hf(:), f(:), g(:), Delta
     integer, intent(in)  :: n, m
     real(wp), intent(out) :: d(:)
     TYPE( nlls_options ), INTENT( IN ) :: options
     TYPE( nlls_inform ), INTENT( INOUT ) :: inform
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
        if ( slls_status .ne. 0 ) goto 1000
     case default
        if (options%print_level> 0) then
           write(options%error,'(a)') 'Error: model not supported in dogleg'
        end if
        inform%status = -3
        return
     end select
     
     if (norm2(w%d_gn) <= Delta) then
        d = w%d_gn
     else if (norm2( alpha * w%d_sd ) >= Delta) then
        d = (Delta / norm2(w%d_sd) ) * w%d_sd
     else
        w%ghat = w%d_gn - alpha * w%d_sd
        call findbeta(w%d_sd,w%ghat,alpha,Delta,beta,fb_status)
        if ( fb_status .ne. 0 ) goto 1010
        d = alpha * w%d_sd + beta * w%ghat
     end if
     
     return
     
1000 continue 
     ! bad error return from solve_LLS
     if ( options%print_level > 0 ) then
        write(options%out,'(a,a)') 'Unexpected error in solving a linear least squares ', &
                                   'problem in dogleg'
        write(options%out,'(a,i0)') 'dposv returned info = ', slls_status
     end if
     inform%status = -700
     return

1010 continue
          if ( options%print_level > 0 ) then
        write(options%out,'(a,a)') 'Unexpected error in finding beta ', &
                                   'in dogleg'
        write(options%out,'(a,i0)') 'dogleg returned info = ', fb_status
     end if
     inform%status = -701
     return

     
   END SUBROUTINE dogleg
     
   SUBROUTINE AINT_tr(J,f,hf,n,m,Delta,d,options,inform,w)
     ! -----------------------------------------
     ! AINT_tr
     ! Solve the trust-region subproblem using 
     ! the method of ADACHI, IWATA, NAKATSUKASA and TAKEDA
     ! -----------------------------------------

     REAL(wp), intent(in) :: J(:), f(:), hf(:), Delta
     integer, intent(in)  :: n, m
     real(wp), intent(out) :: d(:)
     TYPE( nlls_options ), INTENT( IN ) :: options
     TYPE( nlls_inform ), INTENT( INOUT ) :: inform
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
     
     call max_eig(w%M0,w%M1,2*n,lam, w%y, eig_info, y_hardcase,  options, w%max_eig_ws)
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
        if ( find_status .ne. 0 ) goto 1040

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
     if ( options%print_level >= 0 ) then 
        write(options%error,'(a)') 'Error in solving a linear system in AINT_TR'
        write(options%error,'(a,i0)') 'dposv returned info = ', solve_status
     end if
     inform%status = -4
     return
     
1020 continue
     ! bad error return from solve_general
     if ( options%print_level >= 0 ) then 
        write(options%error,'(a)') 'Error in solving a linear system in AINT_TR'
        write(options%error,'(a,i0)') 'dgexv returned info = ', solve_status
     end if
     inform%status = -4
     return
     
1030 continue
     ! bad error return from max_eig
     if ( options%print_level >= 0 ) then 
        write(options%error,'(a)') 'Error in the eigenvalue computation of AINT_TR'
        write(options%error,'(a,i0)') 'dggev returned info = ', eig_info
     end if
     inform%status = -4
     return

1040 continue
     ! no valid beta found
     if ( options%print_level >= 0 ) then 
        write(options%error,'(a)') 'No valid beta found'
     end if
     inform%status = -4
     return

   END SUBROUTINE AINT_tr

   subroutine more_sorensen(J,f,hf,n,m,Delta,d,options,inform,w)
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
     TYPE( nlls_options ), INTENT( IN ) :: options
     TYPE( nlls_inform ), INTENT( INOUT ) :: inform
     type( more_sorensen_work ) :: w

     ! parameters...make these options?
     real(wp) :: nd, nq

     real(wp) :: sigma, alpha
     integer :: fb_status, mineig_status
     integer :: test_pd, i, no_shifts
     
     ! The code finds 
     !  d = arg min_p   v^T p + 0.5 * p^T A p
     !       s.t. ||p|| \leq Delta
     !
     ! set A and v for the model being considered here...
     
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
        sigma = -(sigma - options%more_sorensen_shift)
        no_shifts = 1
100     call shift_matrix(w%A,sigma,w%AplusSigma,n)
        call solve_spd(w%AplusSigma,-w%v,w%LtL,d,n,test_pd)
        if ( test_pd .ne. 0 ) then
           no_shifts = no_shifts + 1
           if ( no_shifts == 10 ) goto 3000
           sigma =  sigma + (10**no_shifts) * options%more_sorensen_shift
           if (options%print_level >=3) write(options%out,2000) sigma
           goto 100 
        end if
     end if
     
     nd = norm2(d)
     if (nd .le. Delta) then
        ! we're within the tr radius from the start!
        if ( abs(sigma) < options%more_sorensen_tiny ) then
           ! we're good....exit
           goto 1050
        else if ( abs( nd - Delta ) < options%more_sorensen_tiny ) then
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
     do i = 1, options%more_sorensen_maxits
        if ( abs(nd - Delta) <= options%more_sorensen_tol * Delta) then
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
     
1020 continue
     ! Converged!
     if ( options%print_level >= 3 ) then
        write(options%error,'(a,i0)') 'More-Sorensen converged at iteration ', i
     end if
     return
     
1040 continue
     ! maxits reached, not converged
     if ( options%print_level > 0 ) then
        write(options%error,'(a)') 'Maximum iterations reached in More-Sorensen'
        write(options%error,'(a)') 'without convergence'
     end if
     inform%status = -100 ! fix me
     return

1050 continue
     if ( options%print_level >= 3 ) then
        write(options%error,'(a)') 'More-Sorensen: first point within trust region'
     end if
     return

1060 continue
     if ( options%print_level > 0 ) then
        write(options%error,'(a)') 'More-Sorensen: error from lapack routine dsyev(x)'
        write(options%error,'(a,i0)') 'info = ', mineig_status
     end if
     inform%status = -333

     return

1070 continue
     if ( options%print_level >= 3 ) then
        write(options%error,'(a)') 'M-S: Unable to find alpha s.t. ||s + alpha v|| = Delta'
     end if
     inform%status = -200

     return
     
2000 format('Non-spd system in more_sorensen. Increasing sigma to ',es12.4)

3000 continue 
     ! bad error return from solve_spd
     if ( options%print_level > 0 ) then
        write(options%out,'(a)') 'Unexpected error in solving a linear system in More_sorensen'
        write(options%out,'(a,i0)') 'dposv returned info = ', test_pd
     end if
     inform%status = -500
     return
     
2010 continue 
     ! bad error return from solve_spd
     if ( options%print_level > 0 ) then
        write(options%out,'(a,a)') 'Unexpected error in solving a linear system ', &
                                   'in More_sorensen loop'
        write(options%out,'(a,i0)') 'dposv returned info = ', test_pd
     end if
     inform%status = -600
     return
     
     
   end subroutine more_sorensen
   
   subroutine solve_dtrs(J,f,hf,n,m,Delta,d,w,options,inform)

     !---------------------------------------------
     ! solve_dtrs
     ! Solve the trust-region subproblem using
     ! the DTRS method from Galahad
     ! 
     ! This method needs H to be diagonal, so we need to 
     ! pre-process
     !
     ! main output :: d, the soln to the TR subproblem
     !--------------------------------------------

     REAL(wp), intent(in) :: J(:), f(:), hf(:), Delta
     integer, intent(in)  :: n, m
     real(wp), intent(out) :: d(:)
     type( solve_dtrs_work ) :: w
     TYPE( nlls_options ), INTENT( IN ) :: options
     TYPE( nlls_inform ), INTENT( INOUT ) :: inform

     integer :: eig_status
     TYPE ( DTRS_CONTROL_TYPE ) :: dtrs_options
     TYPE ( DTRS_inform_type )  :: dtrs_inform
     
     ! The code finds 
     !  d = arg min_p   w^T p + 0.5 * p^T D p
     !       s.t. ||p|| \leq Delta
     !
     ! where D is diagonal
     !
     ! our probem in naturally in the form
     ! 
     ! d = arg min_p   v^T p + 0.5 * p^T H p
     !       s.t. ||p|| \leq Delta
     !
     ! first, find the matrix H and vector v
     ! Set A = J^T J
     call matmult_inner(J,n,m,w%A)
     ! add any second order information...
     ! so A = J^T J + HF
     w%A = w%A + reshape(hf,(/n,n/))

     ! now form v = J^T f 
     call mult_Jt(J,n,m,f,w%v)

     ! Now that we have the unprocessed matrices, we need to get an 
     ! eigendecomposition to make A diagonal
     !
     call all_eig_symm(w%A,n,w%ew,w%ev,w%all_eig_symm_ws,eig_status)
     if (eig_status .ne. 0) goto 1000

     ! We can now change variables, setting y = Vp, getting
     ! Vd = arg min_(Vx) v^T p + 0.5 * (Vp)^T D (Vp)
     !       s.t.  ||x|| \leq Delta
     ! <=>
     ! Vd = arg min_(Vx) V^Tv^T (Vp) + 0.5 * (Vp)^T D (Vp)
     !       s.t.  ||x|| \leq Delta
     ! <=>

     ! we need to get the transformed vector v
     call mult_Jt(w%ev,n,n,w%v,w%v_trans)

     ! we've now got the vectors we need, pass to dtrs_solve
     call dtrs_initialize( dtrs_options, dtrs_inform ) 

     call dtrs_solve(n, Delta, zero, w%v_trans, w%ew, w%d_trans, dtrs_options, dtrs_inform )
     if ( dtrs_inform%status .ne. 0) goto 1010

     ! and return the un-transformed vector
     call mult_J(w%ev,n,n,w%d_trans,d)

     return
     
1000 continue
     if ( options%print_level > 0 ) then
        write(options%error,'(a)') 'solve_dtrs: error from lapack routine dsyev(x)'
        write(options%error,'(a,i0)') 'info = ', eig_status
     end if
     inform%status = -333
     return

1010 continue
     if ( options%print_level > 0 ) then
        write(options%error,'(a)') 'solve_dtrs: error from GALAHED routine DTRS'
        write(options%error,'(a,i0)') 'info = ', dtrs_inform%status
     end if
     inform%status = -777
     return

   end subroutine solve_dtrs


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
! Input:
! f = f(x_k), J = J(x_k), 
! hf = \sum_{i=1}^m f_i(x_k) \nabla^2 f_i(x_k) (or an approx)
!
! We have a model 
!      m_k(d) = 0.5 f^T f  + d^T J f + 0.5 d^T (J^T J + HF) d
!
! This subroutine evaluates the model at the point d 
! This value is returned as the scalar
!       md :=m_k(d)
! --------------------------------------------------       

       real(wp), intent(in) :: f(:) ! f(x_k)
       real(wp), intent(in) :: d(:) ! direction in which we move
       real(wp), intent(in) :: J(:) ! J(x_k) (by columns)
       real(wp), intent(in) :: hf(:)! (approx to) \sum_{i=1}^m f_i(x_k) \nabla^2 f_i(x_k)
       integer, intent(in) :: m,n
       real(wp), intent(out) :: md  ! m_k(d)
       TYPE( nlls_options ), INTENT( IN ) :: options
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
     
     subroutine calculate_rho(normf,normfnew,md,rho)
       !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
       ! Calculate the quantity                                   ! 
       !   rho = 0.5||f||^2 - 0.5||fnew||^2 =   actual_reduction  !
       !         --------------------------   ------------------- !
       !             m_k(0)  - m_k(d)         predicted_reduction !
       !                                                          !
       ! if model is good, rho should be close to one             !
       !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

       real(wp), intent(in)  :: normf    ! ||f(x_k)|| at 
       real(wp), intent(in)  :: normfnew ! ||f(x_k + d)||
       real(wp), intent(in)  :: md       !    m_k(d)
       real(wp), intent(out) :: rho      ! act_red / pred_red (close to 1 == good)

       real(wp) :: actual_reduction, predicted_reduction
       
       actual_reduction = ( 0.5 * normf**2 ) - ( 0.5 * normfnew**2 )
       predicted_reduction = ( ( 0.5 * normf**2 ) - md )
       
       if ( abs(actual_reduction) < 10*epsmch ) then 
          rho = one
       else if (abs( predicted_reduction ) < 10 * epsmch ) then 
          rho = one
       else
          rho = actual_reduction / predicted_reduction
       end if


     end subroutine calculate_rho

     subroutine apply_second_order_info(status,n,m,&
          X,f,hf,eval_Hf,&
          d, y, y_sharp, & 
          params,options,inform)
       integer, intent(out) :: status
       integer, intent(in)  :: n, m 
       real(wp), intent(in) :: X(:), f(:)
       real(wp), intent(inout) :: hf(:)
       real(wp), intent(in) :: d(:), y(:), y_sharp(:)
       procedure( eval_hf_type ) :: eval_Hf
       class( params_base_type ) :: params
       type( nlls_options ), intent(in) :: options
       type( nlls_inform ), intent(inout) :: inform
       
       real(wp), allocatable :: Sks(:), ysharpSks(:)

       real(wp) :: yts, alpha
       integer :: i,j

       if (options%exact_second_derivatives) then
          call eval_HF(status, n, m, X, f, hf, params)
          inform%h_eval = inform%h_eval + 1
       else

          yts = dot_product(d,y)
          allocate(Sks(n))
          call mult_J(hf,n,n,d,Sks) ! hfs = S_k * d

          allocate(ysharpSks(n))
          ysharpSks = y_sharp - Sks
          
          ! now, let's scale hd (Nocedal and Wright, Section 10.2)
          alpha = abs(dot_product(d,y_sharp))/abs(dot_product(d,Sks))
          alpha = min(one,alpha)
          hf(:)  = alpha * hf(:)

          ! update S_k (again, as in N&W, Section 10.2)

          ! hf = hf + (1/yts) (y# - Sk d)^T y:
          alpha = 1/yts
          call dGER(n,n,alpha,ysharpSks,1,y,1,hf,n)
          ! hf = hf + (1/yts) y^T (y# - Sk d):
          call dGER(n,n,alpha,y,1,ysharpSks,1,hf,n)
          ! hf = hf - ((y# - Sk d)^T d)/((yts)**2)) * y y^T
          alpha = -dot_product(ysharpSks,d)/(yts**2)
          call dGER(n,n,alpha,y,1,y,1,hf,n)
                    
       end if

     end subroutine apply_second_order_info

     subroutine update_trust_region_radius(rho,options,Delta)
       
       real(wp), intent(inout) :: rho ! ratio of actual to predicted reduction
       type( nlls_options ), intent(in) :: options
       real(wp), intent(inout) :: Delta ! trust region size
       
       if (rho < options%eta_successful) then
          ! unsuccessful....reduce Delta
          Delta = max( options%radius_reduce, options%radius_reduce_max) * Delta
          if (options%print_level > 2) write(options%out,3010) Delta     
       else if (rho < options%eta_very_successful) then 
          ! doing ok...retain status quo
          if (options%print_level > 2) write(options%out,3020) Delta 
       else if (rho < options%eta_too_successful ) then
          ! more than very successful -- increase delta
          Delta = min(options%maximum_radius, options%radius_increase * Delta )
          if (options%print_level > 2) write(options%out,3030) Delta
       else if (rho >= options%eta_too_successful) then
          ! too successful....accept step, but don't change Delta
          if (options%print_level > 2) write(options%out,3040) Delta 
       else
          ! just incase (NaNs and the like...)
          if (options%print_level > 2) write(options%out,3010) Delta 
          Delta = max( options%radius_reduce, options%radius_reduce_max) * Delta
          rho = -one ! set to be negative, so that the logic works....
       end if 

       return
       
! print statements

3010   FORMAT('Unsuccessful step -- decreasing Delta to', ES12.4)      
3020   FORMAT('Successful step -- Delta staying at', ES12.4)     
3030   FORMAT('Very successful step -- increasing Delta to', ES12.4)
3040   FORMAT('Step too successful -- Delta staying at', ES12.4)   
       

     end subroutine update_trust_region_radius
     
     subroutine test_convergence(normF,normJF,normF0,normJF0,options,inform)
       
       real(wp), intent(in) :: normF, normJf, normF0, normJF0
       type( nlls_options ), intent(in) :: options
       type( nlls_inform ), intent(inout) :: inform

       if ( normF <= max(options%stop_g_absolute, &
            options%stop_g_relative * normF0) ) then
          inform%convergence_normf = 1
          return
       end if
       
       if ( (normJF/normF) <= max(options%stop_g_absolute, &
            options%stop_g_relative * (normJF0/normF0)) ) then
          inform%convergence_normg = 1
       end if
          
       return
       
     end subroutine test_convergence
     
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

      subroutine solve_spd(A,b,LtL,x,n,status)
        REAL(wp), intent(in) :: A(:,:)
        REAL(wp), intent(in) :: b(:)
        REAL(wp), intent(out) :: LtL(:,:)
        REAL(wp), intent(out) :: x(:)
        integer, intent(in) :: n
        integer, intent(out) :: status

        ! A wrapper for the lapack subroutine dposv.f
        ! get workspace for the factors....
        status = 0
        LtL(1:n,1:n) = A(1:n,1:n)
        x(1:n) = b(1:n)
        call dposv('L', n, 1, LtL, n, x, n, status)
           
      end subroutine solve_spd

      subroutine solve_general(A,b,x,n,status,w)
        REAL(wp), intent(in) :: A(:,:)
        REAL(wp), intent(in) :: b(:)
        REAL(wp), intent(out) :: x(:)
        integer, intent(in) :: n
        integer, intent(out) :: status
        type( solve_general_work ) :: w
        
        ! A wrapper for the lapack subroutine dposv.f
        ! NOTE: A would be destroyed
        w%A(1:n,1:n) = A(1:n,1:n)
        x(1:n) = b(1:n)
        call dgesv( n, 1, w%A, n, w%ipiv, x, n, status)
        
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

      subroutine all_eig_symm(A,n,ew,ev,w,status)
        ! calculate all the eigenvalues of A (symmetric)

        real(wp), intent(in) :: A(:,:)
        integer, intent(in) :: n
        real(wp), intent(out) :: ew(:), ev(:,:)
        type( all_eig_symm_work ) :: w
        integer, intent(out) :: status

        real(wp), allocatable :: work
        real(wp) :: tol
        integer :: lwork
        
        status = 0 

        ! copy the matrix A into the eigenvector array
        ev(1:n,1:n) = A(1:n,1:n)
        
        lwork = size(w%work)
        ! call dsyev --> all eigs of a symmetric matrix
        
        call dsyev('V', & ! both ew's and ev's 
             'U', & ! upper triangle of A
             n, ev, n, & ! data about A
             ew, w%work, lwork, & 
             status)
        
      end subroutine all_eig_symm

      subroutine min_eig_symm(A,n,ew,ev,options,status,w)
        ! calculate the leftmost eigenvalue of A
        
        real(wp), intent(in) :: A(:,:)
        integer, intent(in) :: n
        real(wp), intent(out) :: ew, ev(:)
        integer, intent(out) :: status
        type( nlls_options ), INTENT( IN ) :: options
        type( min_eig_symm_work ) :: w

        real(wp) :: tol, dlamch
        integer :: lwork, eigsout, minindex(1)

        tol = 2*dlamch('S')!1e-15
        
        status = 0
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
                status)
           
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
                status)

        end if
           
        ! let the calling subroutine handle the errors
        
        return
                      
      end subroutine min_eig_symm

      subroutine max_eig(A,B,n,ew,ev,status,nullevs,options,w)
        
        real(wp), intent(inout) :: A(:,:), B(:,:)
        integer, intent(in) :: n 
        real(wp), intent(out) :: ew, ev(:)
        integer, intent(out) :: status
        real(wp), intent(out), allocatable :: nullevs(:,:)
        type( nlls_options ), intent(in) :: options
        type( max_eig_work ) :: w
        
        integer :: lwork, maxindex(1), no_null, halfn
        real(wp):: tau
        integer :: i 

        ! Find the max eigenvalue/vector of the generalized eigenproblem
        !     A * y = lam * B * y
        ! further, if ||y(1:n/2)|| \approx 0, find and return the 
        ! eigenvectors y(n/2+1:n) associated with this

        status = 0
        ! check that n is even (important for hard case -- see below)
        if (modulo(n,2).ne.0) goto 1010
        
        halfn = n/2
        lwork = size(w%work)
        call dggev('N', & ! No left eigenvectors
                   'V', &! Yes right eigenvectors
                   n, A, n, B, n, &
                   w%alphaR, w%alphaI, w%beta, & ! eigenvalue data
                   w%vr, n, & ! not referenced
                   w%vr, n, & ! right eigenvectors
                   w%work, lwork, status)

        ! now find the rightmost real eigenvalue
        w%vecisreal = .true.
        where ( abs(w%alphaI) > 1e-8 ) w%vecisreal = .false.
        
        w%ew_array(:) = w%alphaR(:)/w%beta(:)
        maxindex = maxloc(w%ew_array,w%vecisreal)
        if (maxindex(1) == 0) goto 1000
        
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

        return 

1000    continue 
        if ( options%print_level >=0 ) then
           write(options%error,'(a)') 'Error, all eigs are imaginary'
        end if
        status = 1 ! Eigs imaginary error
        
        return

1010    continue
        if (options%print_level >= 0 ) then 
           write(options%error,'(a)') 'error : non-even sized matrix sent to max eig'
        end if
        status = 2

        return

                
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

      subroutine get_svd_J(n,m,J,s1,sn,options,status)
        integer, intent(in) :: n,m 
        real(wp), intent(in) :: J(:)
        real(wp), intent(out) :: s1, sn
        type( nlls_options ) :: options
        integer, intent(out) :: status

        character :: jobu(1), jobvt(1)
        real(wp), allocatable :: Jcopy(:)
        real(wp), allocatable :: S(:)
        real(wp), allocatable :: work(:)
        integer :: lwork
        
        allocate(Jcopy(n*m))
        allocate(S(n))
        Jcopy(:) = J(:)

        jobu  = 'N' ! calculate no left singular vectors
        jobvt = 'N' ! calculate no right singular vectors
        
        allocate(work(1))
        ! make a workspace query....
        call dgesvd( jobu, jobvt, n, m, Jcopy, n, S, S, 1, S, 1, & 
             work, -1, status )
        if (status .ne. 0 ) return

        lwork = int(work(1))
        deallocate(work)
        allocate(work(lwork))     
        
        ! call the real thing....
        call dgesvd( JOBU, JOBVT, n, m, Jcopy, n, S, S, 1, S, 1, & 
             work, lwork, status )
        if ( (status .ne. 0) .and. (options%print_level > 3) ) then 
           write(options%out,'(a,i0)') 'Error when calculating svd, dgesvd returned', &
                                        status
           s1 = -1.0
           sn = -1.0
           ! allow to continue, but warn user and return zero singular values
        else
           s1 = S(1)
           sn = S(n)
           if (options%print_level > 3) then 
              write(options%out,'(a,es12.4,a,es12.4)') 's1 = ', s1, '    sn = ', sn
              write(options%out,'(a,es12.4)') 'k(J) = ', s1/sn
           end if
        end if

      end subroutine get_svd_J


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!                                                       !!
!! W O R K S P A C E   S E T U P   S U B R O U T I N E S !!
!!                                                       !!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      subroutine setup_workspaces(workspace,n,m,options,status)
        
        type( NLLS_workspace ), intent(out) :: workspace
        type( nlls_options ), intent(in) :: options
        integer, intent(in) :: n,m
        integer, intent(out) :: status

        status = 0      
        
        workspace%first_call = 0

        if (.not. options%exact_second_derivatives) then
           if (.not. allocated(workspace%y)) then
              allocate(workspace%y(n), stat = status)
              if (status > 0) goto 9000
           end if
           if (.not. allocated(workspace%y_sharp)) then
              allocate(workspace%y_sharp(n), stat = status)
              if (status > 0) goto 9000
           end if
           if (.not. allocated(workspace%g_old)) then
              allocate(workspace%g_old(n), stat = status)
              if (status > 0) goto 9000
           end if
           if (.not. allocated(workspace%g_mixed)) then
              allocate(workspace%g_mixed(n), stat = status)
              if (status > 0) goto 9000
           end if

        end if

        if( options%output_progress_vectors ) then 
           if (.not. allocated(workspace%resvec)) then
              allocate(workspace%resvec(options%maxit+1), stat = status)
              if (status > 0) goto 9000
           end if
           if (.not. allocated(workspace%gradvec)) then
              allocate(workspace%gradvec(options%maxit+1), stat = status)
              if (status > 0) goto 9000
           end if
        end if

        if( options%model == 8 ) then 
           if (.not. allocated(workspace%fNewton)) then
              allocate(workspace%fNewton(m), stat = status)
              if (status > 0) goto 9000
           end if
           if (.not. allocated(workspace%JNewton)) then
              allocate(workspace%JNewton(n*m), stat = status)
              if (status > 0) goto 9000
           end if
           if (.not. allocated(workspace%XNewton)) then
              allocate(workspace%XNewton(n), stat = status)
              if (status > 0) goto 9000
           end if
        end if
                
        if( .not. allocated(workspace%J)) then
           allocate(workspace%J(n*m), stat = status)
           if (status > 0) goto 9000
        end if
        if( .not. allocated(workspace%f)) then
           allocate(workspace%f(m), stat = status)
           if (status > 0) goto 9000
        end if
        if( .not. allocated(workspace%fnew)) then 
           allocate(workspace%fnew(m), stat = status)
           if (status > 0) goto 9000
        end if
        if( .not. allocated(workspace%hf)) then
           allocate(workspace%hf(n*n), stat = status)
           if (status > 0) goto 9000
        end if
        if( .not. allocated(workspace%d)) then
           allocate(workspace%d(n), stat = status)
           if (status > 0) goto 9000
        end if
        if( .not. allocated(workspace%g)) then
           allocate(workspace%g(n), stat = status)
           if (status > 0) goto 9000
        end if
        if( .not. allocated(workspace%Xnew)) then
           allocate(workspace%Xnew(n), stat = status)
           if (status > 0) goto 9000
        end if


        select case (options%nlls_method)
        
        case (1) ! use the dogleg method
           call setup_workspace_dogleg(n,m,workspace%calculate_step_ws%dogleg_ws, & 
                options, status)
           if (status > 0) goto 9000

        case(2) ! use the AINT method
           call setup_workspace_AINT_tr(n,m,workspace%calculate_step_ws%AINT_tr_ws, & 
                options, status)
           if (status > 0) goto 9010
           
        case(3) ! More-Sorensen 
           call setup_workspace_more_sorensen(n,m,&
                workspace%calculate_step_ws%more_sorensen_ws,options,status)
           if (status > 0) goto 9000

        case (4) ! dtrs (Galahad)
           call setup_workspace_solve_dtrs(n,m, & 
                workspace%calculate_step_ws%solve_dtrs_ws, options, status)

        end select

! evaluate model in the main routine...       
        call setup_workspace_evaluate_model(n,m,workspace%evaluate_model_ws,options,status)
        if (status > 0) goto 9010

        return

! Error statements
9000    continue
        ! Allocation errors : dogleg
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating local array: ',&
                'not enough memory.' 
           write(options%error,'(a,i0)') 'status = ', status
 
        end if
        return
       
9010    continue 
        
        return

      end subroutine setup_workspaces

      subroutine remove_workspaces(workspace,options)
        
        type( NLLS_workspace ), intent(out) :: workspace
        type( nlls_options ), intent(in) :: options

        workspace%first_call = 0

        if(allocated(workspace%y)) deallocate(workspace%y)
        if(allocated(workspace%y_sharp)) deallocate(workspace%y_sharp)
        if(allocated(workspace%g_old)) deallocate(workspace%g_old)
        if(allocated(workspace%g_mixed)) deallocate(workspace%g_mixed)
        
        if(allocated(workspace%resvec)) deallocate(workspace%resvec)
        if(allocated(workspace%gradvec)) deallocate(workspace%gradvec)
        
        if(allocated(workspace%fNewton)) deallocate(workspace%fNewton )
        if(allocated(workspace%JNewton)) deallocate(workspace%JNewton )
        if(allocated(workspace%XNewton)) deallocate(workspace%XNewton ) 
                
        if(allocated(workspace%J)) deallocate(workspace%J ) 
        if(allocated(workspace%f)) deallocate(workspace%f ) 
        if(allocated(workspace%fnew)) deallocate(workspace%fnew ) 
        if(allocated(workspace%hf)) deallocate(workspace%hf ) 
        if(allocated(workspace%d)) deallocate(workspace%d ) 
        if(allocated(workspace%g)) deallocate(workspace%g ) 
        if(allocated(workspace%Xnew)) deallocate(workspace%Xnew ) 
        
        select case (options%nlls_method)
        
        case (1) ! use the dogleg method
           call remove_workspace_dogleg(workspace%calculate_step_ws%dogleg_ws, & 
                options)

        case(2) ! use the AINT method
           call remove_workspace_AINT_tr(workspace%calculate_step_ws%AINT_tr_ws, & 
                options)
           
        case(3) ! More-Sorensen 
           call remove_workspace_more_sorensen(&
                workspace%calculate_step_ws%more_sorensen_ws,options)

        case (4) ! dtrs (Galahad)
           call remove_workspace_solve_dtrs(& 
                workspace%calculate_step_ws%solve_dtrs_ws, options)

        end select

! evaluate model in the main routine...       
        call remove_workspace_evaluate_model(workspace%evaluate_model_ws,options)

        return

      end subroutine remove_workspaces


      subroutine setup_workspace_dogleg(n,m,w,options,status)
        integer, intent(in) :: n, m 
        type( dogleg_work ), intent(out) :: w
        type( nlls_options ), intent(in) :: options
        integer, intent(inout) :: status

        allocate(w%d_sd(n),stat = status)
        if (status > 0) goto 9000
        allocate(w%d_gn(n),stat = status)
        if (status > 0) goto 9000           
        allocate(w%ghat(n),stat = status)
        if (status > 0) goto 9000
        allocate(w%Jg(m),stat = status)
        if (status > 0) goto 9000
        ! setup space for 
        !   solve_LLS
        call setup_workspace_solve_LLS(n,m,w%solve_LLS_ws,options,status)
        if (status > 0 ) goto 9010
        ! setup space for 
        !   evaluate_model
        call setup_workspace_evaluate_model(n,m,w%evaluate_model_ws,options,status)
        if (status > 0 ) goto 9010

        return

        ! Error statements
9000    continue
        ! Allocation errors : dogleg
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for subroutine ''dogleg'': ',&
                'not enough memory.' 
           write(options%error,'(a,i0)') 'status = ', status
 
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

      subroutine remove_workspace_dogleg(w,options)
        type( dogleg_work ), intent(out) :: w
        type( nlls_options ), intent(in) :: options

        if(allocated( w%d_sd )) deallocate(w%d_sd ) 
        if(allocated( w%d_gn )) deallocate(w%d_gn )
        if(allocated( w%ghat )) deallocate(w%ghat )
        if(allocated( w%Jg )) deallocate(w%Jg )
        
        ! deallocate space for 
        !   solve_LLS
        call remove_workspace_solve_LLS(w%solve_LLS_ws,options)
        ! deallocate space for 
        !   evaluate_model
        call remove_workspace_evaluate_model(w%evaluate_model_ws,options)

        return

      end subroutine remove_workspace_dogleg

      subroutine setup_workspace_solve_LLS(n,m,w,options,status)
        integer, intent(in) :: n, m 
        type( solve_LLS_work ) :: w 
        type( nlls_options ), intent(in) :: options
        integer, intent(inout) :: status
        integer :: lwork
        
        allocate( w%temp(max(m,n)), stat = status)
        if (status > 0) goto 9000
        lwork = max(1, min(m,n) + max(min(m,n), 1)*4) 
        allocate( w%work(lwork), stat = status)
        if (status > 0) goto 9000
        allocate( w%Jlls(n*m), stat = status)
        if (status > 0) goto 9000
        
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

      subroutine remove_workspace_solve_LLS(w,options)
        type( solve_LLS_work ) :: w 
        type( nlls_options ), intent(in) :: options
        
        if(allocated( w%temp )) deallocate( w%temp)
        if(allocated( w%work )) deallocate( w%work ) 
        if(allocated( w%Jlls )) deallocate( w%Jlls ) 
        
        return
                
      end subroutine remove_workspace_solve_LLS

      subroutine setup_workspace_evaluate_model(n,m,w,options,status)
        integer, intent(in) :: n, m        
        type( evaluate_model_work ) :: w
        type( nlls_options ), intent(in) :: options
        integer, intent(out) :: status
        
        allocate( w%Jd(m), stat = status )
        if (status > 0) goto 9000
        allocate( w%Hd(n), stat = status)
        if (status > 0) goto 9000

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

      subroutine remove_workspace_evaluate_model(w,options)
        type( evaluate_model_work ) :: w
        type( nlls_options ), intent(in) :: options
        
        if(allocated( w%Jd )) deallocate( w%Jd ) 
        if(allocated( w%Hd )) deallocate( w%Hd ) 
        
        return

      end subroutine remove_workspace_evaluate_model

      subroutine setup_workspace_AINT_tr(n,m,w,options,status)
        integer, intent(in) :: n, m 
        type( AINT_tr_work ) :: w
        type( nlls_options ), intent(in) :: options
        integer, intent(out) :: status
        
        allocate(w%A(n,n),stat = status)
        if (status > 0) goto 9000
        allocate(w%v(n),stat = status)
        if (status > 0) goto 9000
        allocate(w%B(n,n),stat = status)
        if (status > 0) goto 9000
        allocate(w%p0(n),stat = status)
        if (status > 0) goto 9000
        allocate(w%p1(n),stat = status)
        if (status > 0) goto 9000
        allocate(w%M0(2*n,2*n),stat = status)
        if (status > 0) goto 9000
        allocate(w%M1(2*n,2*n),stat = status)
        if (status > 0) goto 9000
        allocate(w%y(2*n),stat = status)
        if (status > 0) goto 9000
        allocate(w%gtg(n,n),stat = status)
        if (status > 0) goto 9000
        allocate(w%q(n),stat = status)
        if (status > 0) goto 9000
        allocate(w%LtL(n,n),stat = status)
        if (status > 0) goto 9000
        ! setup space for max_eig
        call setup_workspace_max_eig(n,m,w%max_eig_ws,options,status)
        if (status > 0) goto 9010
        call setup_workspace_evaluate_model(n,m,w%evaluate_model_ws,options,status)
        if (status > 0) goto 9010
        ! setup space for the solve routine
        if ((options%model .ne. 1).and.(options%model .ne. 3)) then
           call setup_workspace_solve_general(n,m,w%solve_general_ws,options,status)
           if (status > 0 ) goto 9010
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

      subroutine remove_workspace_AINT_tr(w,options)
        type( AINT_tr_work ) :: w
        type( nlls_options ), intent(in) :: options
        
        if(allocated( w%A )) deallocate(w%A)
        if(allocated( w%v )) deallocate(w%v)
        if(allocated( w%B )) deallocate(w%B)
        if(allocated( w%p0 )) deallocate(w%p0)
        if(allocated( w%p1 )) deallocate(w%p1)
        if(allocated( w%M0 )) deallocate(w%M0)
        if(allocated( w%M1 )) deallocate(w%M1)
        if(allocated( w%y )) deallocate(w%y)
        if(allocated( w%gtg )) deallocate(w%gtg)
        if(allocated( w%q )) deallocate(w%q)
        if(allocated( w%LtL )) deallocate(w%LtL)
        ! setup space for max_eig
        call remove_workspace_max_eig(w%max_eig_ws,options)
        call remove_workspace_evaluate_model(w%evaluate_model_ws,options)
        ! setup space for the solve routine
        if ((options%model .ne. 1).and.(options%model .ne. 3)) then
           call remove_workspace_solve_general(w%solve_general_ws,options)
        end if

        return
        
      end subroutine remove_workspace_AINT_tr

      subroutine setup_workspace_min_eig_symm(n,m,w,options,status)
        integer, intent(in) :: n, m 
        type( min_eig_symm_work) :: w
        type( nlls_options ), intent(in) :: options
        integer, intent(out) :: status
        
        real(wp), allocatable :: workquery(:)
        integer :: lapack_status, lwork, eigsout
        
        allocate(w%A(n,n),stat = status)
        if (status > 0) goto 9000
        
        allocate(workquery(1),stat = status)
        if (status > 0) goto 9000
        lapack_status = 0
        
        if (options%subproblem_eig_fact) then 
           allocate(w%ew(n), stat = status)
           if (status > 0) goto 9000
           
           call dsyev('V', & ! both ew's and ev's 
                'U', & ! upper triangle of A
                n, w%A, n, & ! data about A
                w%ew, workquery, -1, & 
                lapack_status)
        else
           allocate( w%iwork(5*n), stat = status )
           if (status > 0) goto 9000
           allocate( w%ifail(n), stat = status ) 
           if (status > 0) goto 9000
           
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
                      lapack_status)
           if (lapack_status > 0) goto 9020
        end if
        lwork = int(workquery(1))
        deallocate(workquery)
        allocate( w%work(lwork), stat = status )
        if (status > 0) goto 9000

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
 
      subroutine remove_workspace_min_eig_symm(w,options)
        type( min_eig_symm_work) :: w
        type( nlls_options ), intent(in) :: options
        
        if(allocated( w%A )) deallocate(w%A)        

        if (options%subproblem_eig_fact) then 
           if(allocated( w%ew )) deallocate(w%ew)
        else
           if(allocated( w%iwork )) deallocate( w%iwork )
           if(allocated( w%ifail )) deallocate( w%ifail ) 
        end if
        if(allocated( w%work )) deallocate( w%work ) 

        return

      end subroutine remove_workspace_min_eig_symm
      
      subroutine setup_workspace_max_eig(n,m,w,options,status)
        integer, intent(in) :: n, m 
        type( max_eig_work) :: w
        type( nlls_options ), intent(in) :: options
        integer, intent(out) :: status
        real(wp), allocatable :: workquery(:)
        integer :: lapack_status, lwork
        
        allocate( w%alphaR(2*n), stat = status)
        if (status > 0) goto 9000
        allocate( w%alphaI(2*n), stat = status)
        if (status > 0) goto 9000
        allocate( w%beta(2*n),   stat = status)
        if (status > 0) goto 9000
        allocate( w%vr(2*n,2*n), stat = status)
        if (status > 0) goto 9000
        allocate( w%ew_array(2*n), stat = status)
        if (status > 0) goto 9000
        allocate(workquery(1),stat = status)
        if (status > 0) goto 9000
        ! make a workspace query to dggev
        call dggev('N', & ! No left eigenvectors
             'V', &! Yes right eigenvectors
             2*n, 1.0, 2*n, 1.0, 2*n, &
             1.0, 0.1, 0.1, & ! eigenvalue data
             0.1, 2*n, & ! not referenced
             0.1, 2*n, & ! right eigenvectors
             workquery, -1, lapack_status)
        if (lapack_status > 0) goto 9020
        lwork = int(workquery(1))
        deallocate(workquery)
        allocate( w%work(lwork), stat = status)
        if (status > 0) goto 9000
        allocate( w%nullindex(2*n), stat = status)
        if (status > 0) goto 9000
        allocate( w%vecisreal(2*n), stat = status)
        if (status > 0) goto 9000

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

     subroutine remove_workspace_max_eig(w,options)
        type( max_eig_work) :: w
        type( nlls_options ), intent(in) :: options
        
        if(allocated( w%alphaR )) deallocate( w%alphaR)
        if(allocated( w%alphaI )) deallocate( w%alphaI )
        if(allocated( w%beta )) deallocate( w%beta ) 
        if(allocated( w%vr )) deallocate( w%vr ) 
        if(allocated( w%ew_array )) deallocate( w%ew_array ) 
        if(allocated( w%work )) deallocate( w%work ) 
        if(allocated( w%nullindex )) deallocate( w%nullindex ) 
        if(allocated( w%vecisreal )) deallocate( w%vecisreal )

        return
        
      end subroutine remove_workspace_max_eig

      subroutine setup_workspace_solve_general(n, m, w, options, status)
        integer, intent(in) :: n, m 
        type( solve_general_work ) :: w
        type( nlls_options ), intent(in) :: options
        integer, intent(out) :: status
        
        allocate( w%A(n,n), stat = status)
        if (status > 0) goto 9000
        allocate( w%ipiv(n), stat = status)
        if (status > 0) goto 9000
        
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

      subroutine remove_workspace_solve_general(w, options)
        type( solve_general_work ) :: w
        type( nlls_options ), intent(in) :: options
        
        if(allocated( w%A )) deallocate( w%A ) 
        if(allocated( w%ipiv )) deallocate( w%ipiv ) 
        return

      end subroutine remove_workspace_solve_general

      subroutine setup_workspace_solve_dtrs(n,m,w,options,status)
        integer, intent(in) :: n,m
        type( solve_dtrs_work ) :: w
        type( nlls_options ), intent(in) :: options
        integer, intent(out) :: status
        
        allocate(w%A(n,n),stat = status)
        if (status > 0) goto 9000
        allocate(w%ev(n,n),stat = status)
        if (status > 0) goto 9000
        allocate(w%v(n),stat = status)
        if (status > 0) goto 9000
        allocate(w%v_trans(n),stat = status)
        if (status > 0) goto 9000
        allocate(w%ew(n),stat = status)
        if (status > 0) goto 9000
        allocate(w%d_trans(n),stat = status)
        if (status > 0) goto 9000

        call setup_workspace_all_eig_symm(n,m,w%all_eig_symm_ws,options,status)
        if (status > 0) goto 9010
        
        return
                
9000    continue
        ! Allocation errors : solve_dtrs
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for subroutine ''solve_dtrs'': ',&
                'not enough memory.' 
        end if
        
        return
        
9010    continue  
        ! errors : solve_dtrs
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Called from routine solve_dtrs' 
        end if
        
        return

      end subroutine setup_workspace_solve_dtrs

      subroutine remove_workspace_solve_dtrs(w,options)
        type( solve_dtrs_work ) :: w
        type( nlls_options ), intent(in) :: options

        if(allocated( w%A )) deallocate(w%A)
        if(allocated( w%ev )) deallocate(w%ev)
        if(allocated( w%v )) deallocate(w%v)
        if(allocated( w%v_trans )) deallocate(w%v_trans)
        if(allocated( w%ew )) deallocate(w%ew)
        if(allocated( w%d_trans )) deallocate(w%d_trans)

        call remove_workspace_all_eig_symm(w%all_eig_symm_ws,options)
        
        return

      end subroutine remove_workspace_solve_dtrs
      
      subroutine setup_workspace_all_eig_symm(n,m,w,options,status)
        integer, intent(in) :: n,m
        type( all_eig_symm_work ) :: w
        type( nlls_options ), intent(in) :: options
        integer, intent(out) :: status

        real(wp), allocatable :: workquery(:)
        real(wp) :: A,ew
        integer :: lapack_status, lwork, eigsout

        lapack_status = 0
        A = 1.0_wp
        ew = 1.0_wp

        allocate(workquery(1))
        call dsyev('V', & ! both ew's and ev's 
             'U', & ! upper triangle of A
             n, A, n, & ! data about A
             ew, workquery, -1, & 
             lapack_status)  
        if (lapack_status .ne. 0) goto 9000

        lwork = int(workquery(1))
        deallocate(workquery)
        allocate( w%work(lwork), stat = status )
        if (status > 0) goto 8000
        
        return
        
8000    continue 
        ! Allocation errors : all_eig_sym
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for subroutine ''all_eig_symm'': ',&
                'not enough memory.' 
        end if

9000    continue
        ! lapack error
        if (options%print_level >= 0) then
           write(options%error,'(a,a)') &
                'Error allocating array for subroutine ''solve_dtrs'': ',&
                'not enough memory.' 
        end if
        
        return

      end subroutine setup_workspace_all_eig_symm

      subroutine remove_workspace_all_eig_symm(w,options)
        type( all_eig_symm_work ) :: w
        type( nlls_options ), intent(in) :: options

        if(allocated( w%work )) deallocate( w%work ) 

      end subroutine remove_workspace_all_eig_symm
      
      subroutine setup_workspace_more_sorensen(n,m,w,options,status)
        integer, intent(in) :: n,m
        type( more_sorensen_work ) :: w
        type( nlls_options ), intent(in) :: options
        integer, intent(out) :: status
        allocate(w%A(n,n),stat = status)
        if (status > 0) goto 9000
        allocate(w%LtL(n,n),stat = status)
        if (status > 0) goto 9000
        allocate(w%v(n),stat = status)
        if (status > 0) goto 9000
        allocate(w%q(n),stat = status)
        if (status > 0) goto 9000
        allocate(w%y1(n),stat = status)
        if (status > 0) goto 9000
        allocate(w%AplusSigma(n,n),stat = status)
        if (status > 0) goto 9000

        call setup_workspace_min_eig_symm(n,m,w%min_eig_symm_ws,options,status)
        if (status > 0) goto 9010
        
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
      
      subroutine remove_workspace_more_sorensen(w,options)
        type( more_sorensen_work ) :: w
        type( nlls_options ), intent(in) :: options

        if(allocated( w%A )) deallocate(w%A)
        if(allocated( w%LtL )) deallocate(w%LtL)
        if(allocated( w%v )) deallocate(w%v)
        if(allocated( w%q )) deallocate(w%q)
        if(allocated( w%y1 )) deallocate(w%y1)
        if(allocated( w%AplusSigma )) deallocate(w%AplusSigma)

        call remove_workspace_min_eig_symm(w%min_eig_symm_ws,options)
        
        return

      end subroutine remove_workspace_more_sorensen
      

end module ral_nlls_double
