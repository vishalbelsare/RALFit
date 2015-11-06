program driver

use nlls_module
use example_module
implicit none

integer                   :: n, m, i
real(wp), allocatable     :: X(:)
type( NLLS_inform_type )  :: status
type( NLLS_control_type ) :: options
type( user_type ), target :: params

write(*,*) '==============='
write(*,*) 'RAL NLLS driver'
write(*,*) '==============='
write(*,*) ' '

n = 2

m = 67

allocate( X(n) )

X(1) = 1.0 
X(2) = 2.0

options%print_level = 3
options%nlls_method = 2
options%model = 2
options%maxit = 25

! Get params for the function evaluations
allocate(params%x_values(m))
allocate(params%y_values(m))

call generate_data_example(params%x_values,params%y_values,m)

call ral_nlls(n, m, X,                         &
              eval_F, eval_J, eval_H, params,  &
              status, options )

do i = 1,n
   write(*,*) X(i)
end do

end program driver

