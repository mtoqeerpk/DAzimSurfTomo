! Direct Inversion for 3-D Azimuthal Anisotropy
! V1.1 (2017) Based on Mineos to calculate kernel
! V1.2 (2019) Based on CPS-tregn96 to calcualte kernel
! Copyright:
!    Author: Chuanming Liu (at CU Boulder)
!     Email: Chuanming.liu@colorado.edu
! Reference:

program SurfAniso
        use lsmrModule, only:lsmr
        use lsmrblasInterface, only : dnrm2
        use omp_lib
        implicit none

        character inputfile*100
        character logfile*100
        character outmodel*100
        character outsyn*100
        logical ex
        character dummy*40
        character datafile*80
        integer nx,ny,nz
        real goxd,gozd
        real dvxd,dvzd
        integer nsrc,nrc
        real weightVs,weight0,weight1,weightGcs,weight
        real damp,dampAA,dampVs
        real minthk
        integer kmax,kmaxRc
        real*8,dimension(:),allocatable:: tRc
        real,dimension(:),allocatable:: depz
        integer itn
        integer nout
        integer localSize
        real mean,std_devs,balances,balanceb
        integer msurf
        real,dimension(:),allocatable:: obst,dsyn,cbst,dist
        real,dimension(:),allocatable:: pvall
      	real sta1_lat,sta1_lon,sta2_lat,sta2_lon
      	real dist1
        integer dall
       	integer istep
       	real,parameter :: pi=3.1415926535898
       	integer checkstat
       	integer ii,jj,kk
        real, dimension (:,:), allocatable :: scxf,sczf
        real, dimension (:,:,:), allocatable :: rcxf,rczf
        integer,dimension(:,:),allocatable::wavetype,igrt,nrc1
       	integer,dimension(:),allocatable::nsrc1
       	integer,dimension(:,:),allocatable::periods
       	real,dimension(:),allocatable::rw
       	integer,dimension(:),allocatable::iw,col
        real,dimension(:),allocatable::dv
        real,dimension(:,:,:),allocatable::vsf
      	character strf
      	integer veltp,wavetp
      	real velvalue
      	integer knum,knumo,err
      	integer istep1,istep2
      	integer period
      	integer knumi,srcnum,count1
      	integer HorizonType,VerticalType
      	character line*200
        integer iter,maxiter
        integer maxnar
        real acond,anorm,arnorm,rnorm,xnorm
        character str1
        real atol,btol
        real conlim
        integer istop
        integer itnlim
        integer lenrw,leniw
        integer nar,nar_tmp,nars
        integer count3,nvz,nvx
        integer m,maxvp,n
        integer i,j,k
        real spfra
        real noiselevel
        integer ifsyn
        integer writepath
        real averdws
        real maxnorm

        character SenGTruefile*200, SenGfile*200
        integer lay
        integer maxm
        real, dimension(:), allocatable:: sigmaT,resSigma,datweight
        real, dimension(:), allocatable:: Tdata,resbst,fwdT,fwdTvs,fwdTaa,Tref,RefTaa,resbst_iso

        real meandeltaT,stddeltaT
        real,dimension(:,:),allocatable:: GVs,GGs,GGc
        real,dimension(:,:,:), allocatable :: Lsen_Gsc
        real gaussian
        external gaussian
        real synT
        !real,dimension(:,:,:),allocatable::vsRela,vsAbs,vsreal
        real,dimension(:,:,:),allocatable:: gcf,gsf
        integer nar1,nar2
        real vsref
        real res2Norm,Mnorm2,Enorm2,Vsnorm2,Gcnorm2,Gsnorm2
        real resNSigma2Norm
        real Enorm2Lame,Vsnorm2Lame,Gcnorm2Lame,Gsnorm2Lame
        real MwNorm2

        real*8,dimension(:,:),allocatable:: tRcV
        real sumObs
        integer Refwritepath,realwritepath
        real VariGc,VariGs,VariVs
        integer count4,para
        real LambdaVs,LambdaGc,LambdaGs
        real PreRes,meanAbs
        integer iter_mod,rmax
        character(len=2) :: id='00'
        character(len=60) :: filename
        real*8 :: startT,endT
        logical:: isTikh
        real :: summ, threshold0,thresholdVs
        real :: pertV
        logical :: iso_inv, iso_mod
        real Minvel,MaxVel
        real,dimension(:),allocatable:: norm
        ! open output for LSMR
        startT=OMP_get_wtime()
        nout=36
        open(nout,file='lsmr.txt')
        ! terminal output
        write(*,*)
        write(*,*) '                       DSurfAA'
        write(*,*) 'PLEASE contact Chuanming Liu &
            (chuanmingliu@foxmail.com) if you have any problem.'
        write(*,*)

        ! read contral file
        if (iargc() < 1) then
            write(*,*) 'input file [SurfAniso.in (Default)]:'
            read(*,'(a)') inputfile
            if (len_trim(inputfile) <=1 ) then
                inputfile='SurfAniso.in'
            else
                inputfile=inputfile(1:len_trim(inputfile))
            endif
        else
            call getarg(1, inputfile)
        endif
        inquire(file=inputfile, exist=ex)
        if (.not. ex)   stop 'unable to open the inputfile'

        open(10,file=inputfile,status='old',action='read')
        read(10,'(a30)') dummy
        read(10,'(a30)') dummy
        read(10,'(a30)') dummy
        ! read(10,*) SenGfile
        read(10,*) datafile
        read(10,*) nx,ny,nz
        read(10,*) goxd,gozd
        read(10,*) dvxd,dvzd
        read(10,*) minthk
        read(10,*) Minvel,Maxvel
        read(10,*) nsrc
        read(10,*) spfra
        read(10,*) maxiter
        read(10,*) iso_mod
        read(10,'(a30)') dummy
        read(10,*) weight1
        read(10,*) weight0
        read(10,*) dampVs
        read(10,*) dampAA
        ! read(10,*) isTikh
        ! read(10,*) LcorrXY,LcorrZZ
        ! write(*,*) 'integrated  sensitivity kernel for Vs and Gcs file based on MOD  '
        ! write(*,'(a)')SenGfile
        write(*,*)'input Rayleigh wave phase velocity data file:'
        write(*,'(a)') datafile
        write(*,*)  'model origin:latitude,longitue'
        write(*,'(2f10.4)') goxd,gozd
        write(*,*) 'grid spacing:latitude,longitue'
        write(*,'(2f10.4)') dvxd,dvzd
        write(*,*) 'model dimension:nx,ny,nz'
        write(*,'(3i5)') nx,ny,nz
        write(*,*)'depth refined interval layer '
        write(*,'(f8.1)')minthk
        write(*,*)'weight for Vs '
        write(*,'(f8.1)')weight1
        write(*,*)'weight for Gc, Gs '
        write(*,'(f8.1)')weight0
        write(*,*)'damp for Vs '
        write(*,'(f8.1)')dampVs
        write(*,*)'damp for Gc, Gs '
        write(*,'(f8.1)')dampAA
        ! write(*,*)' Regularization Type: (T) 1st order Tikhonov ;(F) Gaussian'
        ! write(*,*) 'correlation length: XY, ZZ (km)'
        ! write(*,'(f8.1)')LcorrXY, LcorrZZ

        if (nz.LE.1)  stop 'error nz value.'
        read(10,'(a30)')dummy
        read(10,*) kmaxRc
        write(*,*) 'number of period'
        write(*,'(i6)') kmaxRc

        if(kmaxRc.gt.0)then
           allocate(tRc(kmaxRc),STAT=checkstat)
           if (checkstat > 0) stop 'error allocating RP'
           read(10,*)(tRc(i),i=1,kmaxRc)
        else
            stop 'Can only deal with Rayleigh wave phase velocity data!'
        endif

	    write(logfile,'(a,a)') trim(inputfile),'_inv.log'
        !open(66,file=logfile,action='write')
        open(66, file=logfile)
        write(66,*)
        write(66,*) '                  DSurfAA'
        write(66,*)'Please contact Chuanming Liu &
             (chuanmingliu@foxmail.com) if you find any bug.'
        write(66,*)
        write(66,*) 'model origin:latitude,longitue'
        write(66,'(2f10.4)') goxd,gozd
        write(66,*) 'grid spacing:latitude,longitue'
        write(66,'(2f10.4)') dvxd,dvzd
        write(66,*) 'model dimension:nx,ny,nz'
        write(66,'(3i5)') nx,ny,nz

        write(*,*)'Rayleigh wave phase velocity used,periods:(s)'
        write(*,'(50f6.1)')(tRc(i),i=1,kmaxRc)
        write(66,*)'Rayleigh wave phase velocity used,periods:(s)'
        write(66,'(50f6.1)')(tRc(i),i=1,kmaxRc)


        ! close(10)
        nrc=nsrc
        kmax=kmaxRc
        lay=nz-1
        !-----------------------------------------------------------------------!
        ! read measurements
        inquire(file=datafile, exist=ex)
        if (.not. ex) then
            write(66,'(a)') 'unable to open the datafile'
            close(66)
            stop 'unable to open the datafile'
        endif
        write(*,*) 'begin load data file.....'

        open(unit=87,file=datafile,status='old')

        allocate(scxf(nsrc,kmax),sczf(nsrc,kmax),&
        rcxf(nrc,nsrc,kmax),rczf(nrc,nsrc,kmax),STAT=checkstat)
        if(checkstat > 0)  write(6,*)'scxf error with allocate','nsrc=',nsrc,'kmax=',kmax

        allocate(periods(nsrc,kmax),wavetype(nsrc,kmax),nrc1(nsrc,kmax),nsrc1(kmax),&
        igrt(nsrc,kmax),STAT=checkstat)
        if(checkstat > 0) write(6,*)'error with allocate'

        allocate(obst(nrc*nsrc*kmax),dist(nrc*nsrc*kmax),STAT=checkstat)
        obst=0
        dist=0
        if(checkstat > 0)  write(6,*)'error with allocate'

        allocate(pvall(nrc*nsrc*kmax),STAT=checkstat)
        if(checkstat > 0)    write(6,*)'error with allocate'

        istep=0
        istep2=0
        dall=0
        knumo=12345
	    knum=0
	    istep1=0
	    pvall=0
        do
            read(87,'(a)',iostat=err) line
            if(err.eq.0) then
                if(line(1:1).eq.'#') then
                   read(line,*) str1, sta1_lat, sta1_lon, period, wavetp, veltp
                   if(wavetp.eq.2.and.veltp.eq.0) knum=period
                   if(wavetp.eq.2.and.veltp.eq.1) stop 'can not deal with Rayleigh wave group data'
                   if(wavetp.eq.1.and.veltp.eq.0) stop 'can not deal with Love wave phase data'
                   if(wavetp.eq.1.and.veltp.eq.1) stop 'can not deal with Love wave group data'
                   if(knum.ne.knumo) then
                       istep=0
                       istep2=istep2+1
                   endif
                   istep=istep+1
                   istep1=0
                   sta1_lat=(90.0-sta1_lat)*pi/180.0
                   sta1_lon=sta1_lon*pi/180.0
                   scxf(istep,knum)=sta1_lat
                   sczf(istep,knum)=sta1_lon
                   periods(istep,knum)=period
                   wavetype(istep,knum)=wavetp
                   igrt(istep,knum)=veltp
                   nsrc1(knum)=istep
                   knumo=knum
                else
                   read(line,*) sta2_lat,sta2_lon,velvalue
                   istep1=istep1+1
                   dall=dall+1
                   sta2_lat=(90.0-sta2_lat)*pi/180.0
                   sta2_lon=sta2_lon*pi/180.0
                   rcxf(istep1,istep,knum)=sta2_lat
                   rczf(istep1,istep,knum)=sta2_lon
                   call delsph(sta1_lat,sta1_lon,sta2_lat,sta2_lon,dist1)
                   dist(dall)=dist1
                   obst(dall)=dist1/velvalue
                   pvall(dall)=velvalue
                   nrc1(istep,knum)=istep1
                endif
            else
                exit
            endif
        enddo
        close(87)
        write(*,'(a,i7)') ' Number of all measurements', dall
        !----------------------------------------------------------------------!
        !  Initialization
        allocate(depz(nz), STAT=checkstat)
        allocate(vsf(nx,ny,nz), STAT=checkstat)

        maxvp=(nx-2)*(ny-2)*(nz-1)
        maxm=(nx-2)*(ny-2)*(nz-1)*2
        maxnar = spfra*dall*nx*ny*nz*2 !sparsity fraction

        allocate(dv(maxm), stat=checkstat)
        allocate(rw(maxnar), STAT=checkstat)
        allocate(iw(2*maxnar+1), STAT=checkstat)
        allocate(col(maxnar), STAT=checkstat)
        allocate(norm(maxvp), stat=checkstat)
        !allocate(cbst(dall+maxm*maxm),dsyn(dall),STAT=checkstat)
        allocate(cbst(dall+maxm*2), dsyn(dall), STAT=checkstat)
        allocate(dsyn(dall), STAT=checkstat)
        allocate(sigmaT(dall), Tref(dall), datweight(dall), STAT=checkstat)
        allocate(Tdata(dall), resbst(dall), fwdT(dall), fwdTvs(dall), fwdTaa(dall), RefTaa(dall), STAT=checkstat)
        allocate(resbst_iso(dall), STAT=checkstat)
        allocate(resSigma(dall), STAT=checkstat)
        allocate(Lsen_Gsc(nx*ny,kmaxRc,nz-1), STAT=checkstat)
        allocate(GVs(dall,maxvp), GGc(dall,maxvp), GGs(dall,maxvp), STAT=checkstat)
        allocate(gcf(nx-2,ny-2,nz-1),gsf(nx-2,ny-2,nz-1), STAT=checkstat)
        allocate( tRcV((nx-2)*(ny-2),kmaxRc), STAT=checkstat)
        !----------------------------------------------------------------------!
        !  read reference isotropic model: vsf
        open(11, file='MOD', status='old')
        vsf=0
        read(11,*) (depz(i),i=1,nz)
        do k = 1,nz
            do j = 1,ny
                read(11,*)(vsf(i,j,k),i=1,nx)
            enddo
        enddo
        close(11)
        write(*,*) ' grid points in depth direction:(km)'
        write(*,'(50f6.2)') depz

        call  CalRmax(nz,depz,minthk,rmax)
        !----------------------------------------------------------------------!
        !                     iteration part
        !----------------------------------------------------------------------!
        !  if iter is odd: invert for  anisotropic model Gc/L,Gs/L (iter = 1, 3, 5)
        !  if iter is even: invert for isotropic model Vs (iter = 2, 4)
        !----------------------------------------------------------------------!
        RefTaa=0
        ! iso_mod=.false.
        open(34, file='IterVel.out')
        do iter=1, maxiter
        iter_mod=mod(iter, 2)
        write(6,*)  ' -----------------------------------------------------------'
        write(66,*) ' -----------------------------------------------------------'

        if ((iter_mod.eq.0) .OR. iso_mod) then
           iso_inv=.true.
           write(66,*)iter,'th iteration, invert for isotropic Vs para.'
           write(6,*) iter,'th iteration, invert for isotropic Vs para.'
           maxm =  maxvp
        else
            iso_inv=.false.
            write(66,*)iter,'th iteration, invert for anisotropic Gc, Gs para.'
            write(6,*) iter,'th iteration, invert for anisotropic Gc, Gs para.'
            maxm =  maxvp*2
        endif
        write(6,*)  ' -----------------------------------------------------------'
        write(66,*) ' -----------------------------------------------------------'
        !----------------------------------------------------------------------!
        ! compute G matrix based on the sensitivity kernel and ray-tracing
        ! forward calculation of traveltime misfit based on the reference iso or aniso model.
        Refwritepath = 0 ! switch of write ray path
        dsyn = 0
        GGc = 0
        GGs = 0
        GVs = 0
        tRcV = 0
        iw = 0
        rw = 0.0
        col = 0
        nar = 0
        Lsen_Gsc=0.0
        if (iso_inv) then
            call CalSurfG(nx,ny,nz,maxvp,vsf,iw,rw,col,dsyn,&
            GVs, dall,&
            goxd, gozd, dvxd, dvzd, kmaxRc, tRc, periods, depz, minthk,&
            scxf, sczf, rcxf, rczf, nrc1, nsrc1, kmax, nsrc, nrc, nar)
        else
            call CalSurfGAniso(nx, ny, nz, maxvp, vsf, iw, rw, col, dsyn, &
            GGc, GGs, Lsen_Gsc, dall, rmax, tRcV, &
            goxd, gozd, dvxd, dvzd, kmaxRc, tRc, periods,depz, minthk,&
            scxf, sczf, rcxf, rczf, nrc1, nsrc1, kmax, nsrc, nrc, nar, Refwritepath)
        endif
        ! write(*,*) ' Finish G matrix calculation.'
        !----------------------------------------------------------------------!
        ! output the corresponding isotropic phase velocity map of the MOD.
        if (iter.eq.1)then
            open(77,file='period_phaseVMOD.dat')
            call WTPeriodPhaseV(nx, ny, gozd, goxd, dvzd, dvxd, kmaxRc, tRc, tRcV, 77)
        end if
        !----------------------------------------------------------------------!
        ! calculate data residual based on the reference iso- or aniso- model.
        ! cbst: travel time residual.
        ! dsyn: predicated isotropic travel time
        ! Tdata: traveltime residual, used in the inversion
        cbst=0
        Tdata=0
        sigmaT=0
        Tref=0
        if (iso_inv) then
            do i = 1,dall
                Tref(i)=dsyn(i)+ RefTaa(i) ! get from previous aniso inv
                cbst(i)=obst(i) - Tref(i)
                Tdata(i)=cbst(i)
            enddo
        else
            do i=1,dall
                Tref(i)=dsyn(i)
                cbst(i)=obst(i) - Tref(i)
                Tdata(i)=cbst(i)
            enddo
        endif
        ! Statistic of the data residual based on the reference model.
        mean=sum(cbst(1:dall))/dall
        std_devs=sqrt(sum((cbst(1:dall)-mean)**2)/dall)
        meanAbs=sum(abs(cbst(1:dall)))/dall


        if (iso_inv) then
            write(66,'(a,f12.4,a,f10.2,a)') '  input data: ISO abs mean and rms of Res (s): ', meanAbs,'s',&
            dnrm2(dall,cbst,1)/sqrt(real(dall)),'s'
            write(6 ,'(a,f12.4,a,f10.2,a)') '  input data: ISO abs mean and rms of Res (s): ', meanAbs,'s',&
            dnrm2(dall,cbst,1)/sqrt(real(dall)),'s'
        else
            write(6 ,'(a, f12.4,a,f10.2,a,f10.2,a)') '  input data: Aniso abs mean, std, rms of Res:', meanAbs,'s',  &
            std_devs,'s', dnrm2(dall,cbst,1)/sqrt(real(dall)),'s'
            write(66,'(a, f12.4,a,f10.2,a,f10.2,a)') '  input data: Aniso abs mean, std, rms of Res', meanAbs,'s',  &
            std_devs,'s', dnrm2(dall,cbst,1)/sqrt(real(dall)),'s'
        endif
        !----------------------------------------------------------------------!
        ! Calculate the sigma (Cd) for the constraint on the data used in the inversion.
	    ! call CalDdatSigma(dall, obst, cbst, sigmaT, meandeltaT, stddeltaT)
	    ! do i=1,dall
        !     cbst(i)=cbst(i)*1/sigmaT(i)
        !     datweight(i)=1/sigmaT(i)
        ! enddo
        ! ! ADDING THE Cd^-1 TO G
        ! do i = 1,nar
        !     rw(i) = rw(i)*1/sigmaT(iw(1+i))
        ! enddo
        datweight=0.0
        if (iso_inv) then
            thresholdVs=0.2
    		do i = 1,dall
    	        datweight(i) = 1.0
    	        if(abs(cbst(i)) > thresholdVs)  datweight(i) = exp(-(abs(cbst(i))-thresholdVs))
		        cbst(i) = cbst(i)*datweight(i)
		    enddo
        else
            ! threshold0: the larger value generate smaller weight, more sensitivity to residual
            threshold0=10
            do i=1,dall
                datweight(i) = 0.01+1.0/(1+0.05*exp(cbst(i)**2*threshold0))
                cbst(i) = cbst(i)*datweight(i)
            enddo
        endif

        do i = 1,nar
            rw(i) = rw(i)*datweight(iw(1+i))
        enddo

        meanAbs=sum(abs(cbst(1:dall)))/dall
        write(6 ,'(a, f10.3, a, f10.3,a)') '  mean data weight:',sum(datweight(1:dall))/dall, '  abs data mean with weight:',meanAbs,'s'
        write(66,'(a, f10.3, a, f10.3,a)') '  mean data weight:',sum(datweight(1:dall))/dall, '  abs data mean with weight:',meanAbs,'s'
        if (iso_mod) then
            norm=0
            do i=1,nar
            norm(col(i))=norm(col(i))+abs(rw(i))
            enddo
        endif
        ! write out res for 1-th and final inversion
        write(id,'(I2.2)') iter
        filename = 'Traveltime_use_'//TRIM(id)//'th.dat'
        open(88, file=filename)
        write(88,'(a)') 'Dist(km)        T_obs(s)       T_forward(s)         Res(s)        weight        W_Res'
        do i=1,dall
            write(88,*) dist(i), obst(i), dsyn(i), Tdata(i), datweight(i), cbst(i)
        enddo
        close(88)
        !----------------------------------------------------------------------!
        ! Setting with iteration.
        ! After 1st iteration, use the res2Norm and Mnorm2 to set weight value in the next iteration.
        !----------------------------------------------------------------------!
        ! A*x = b
        ! m       input      m, the number of rows in A. (data)
        ! n       input      n, the number of columns in A. (model)
        ! count3: data, d, counter index
        ! nar: number of G which value is not zero, including augmented matrix.
        !      if Gn*m does not contain zeros,  nar =n*m
        ! rw(i) gives value of the i-th non-zero value of G
        ! iw(i+1) means this value is in the iw(i+1)-th row.
        ! col(i) means this value is in the col(i)-th column. = iw(i+1+nar)
        !----------------------------------------------------------------------!
        nar1=nar
        weightGcs=weight0
        weightVs=dnrm2(dall,cbst,1)**2/dall*weight1
        count3=0

        call TikhonovRegularization(nx, ny, nz, maxvp, dall, nar, rw, iw, col, count3, iso_inv, weightGcs, weightVs)
        forall(i=1:count3)
           cbst(dall+i)=0
        end forall
        !----------------------------------------------------------------------!
        !----------------------------------------------------------------------!
        m = dall + count3 ! data number, rows
        n = maxm          ! model number, columns
        iw(1) = nar
        do i=1,nar
           iw(1+nar+i)=col(i)
        enddo

        if (nar > maxnar) stop 'increase sparsity fraction(spfra)'
        if (iso_inv)then
            damp=dampVs
            write(*  ,'(a,2f8.2)') '  weight and  damp for dVs:',weightVs, dampVs
            write(66 ,'(a,2f8.2)') '  weight and  damp for dVs:',weightVs, dampVs
        else
            damp=dampAA
            write(*  ,'(a,2f8.1)') '  weight and damp for Gcs: ',weightGcs, dampAA
            write(66 ,'(a,2f8.1)') '  weight and damp for Gcs: ',weightGcs, dampAA
        endif

        leniw = 2*nar+1
        lenrw = nar
        dv = 0
        ! Control of LSQR
        ! atol:   estimate of error to G, accurate to about 4 digits, set btol = 1.0e-4. (default AA: 1e-4)
        ! btol:   estimate of error to data, accurate to about 4 digits, set btol = 1.0e-4. (default AA: 1e-4)
        ! conlim: the apparent condition number of the matrix Abar, controls the amp of Gc,s
        !         conlim and damp may be used separately or together to regularize ill-conditioned systems.
        ! itnlim: an upper limit on the number of iterations.
        if (iso_inv) then
            ! atol = 1e-5
            ! btol = 1e-4
            ! conlim = 200
            ! itnlim = 400
            atol = 1e-3
            btol = 1e-3
            conlim = 1200
            itnlim = 1000
            localSize = n/4
        else
            atol = 1e-5
            btol = 1e-4
            conlim = 200
            itnlim = 400
            localSize = 10
        endif

        istop = 0
        anorm = 0.0
        acond = 0.0
        arnorm = 0.0
        xnorm = 0.0

        call LSMR(m, n, leniw, lenrw, iw, rw, cbst, damp,&
        atol, btol, conlim, itnlim, localSize, nout,&
        dv, istop, itn, anorm, acond, rnorm, arnorm, xnorm)
        if(istop==3) THEN
            write(* , '(a)') '  istop = 3, large condition number, LSMR failed'
            write(66, '(a)') '  istop = 3, large condition number, LSMR failed'
        endif
        write(*,'(a)') '  Finish LSMR.......'
        write(*, '(a, i7)')  '  itn=               ',itn
        write(66,'(a, i7)')  '  itn=               ',itn
        write(*,'(a, f7.1)') '  L2 norm of A=      ',anorm
        write(*, '(a, f7.1)')'  Condition NO. of A=',acond
        write(66,'(a, f7.1)')'  Condition NO. of A=',acond
        write(*,'(a, f7.1)') '  rnorm=             ',rnorm
        write(*,'(a, f7.1)') '  arnorm=            ',arnorm
        write(*,'(a, f7.3)') '  norm of dv =       ',xnorm
        !----------------------------------------------------------------------!
        ! Based on perturbation, construct isotropic or anisotropic velocity model
        ! For vsRela will be used in subroutine: CalSurfGAniso, it will be important to get a right value.
        ! vsf initially comes from MOD, then updates from even iteration.
        if (iso_inv) then
            do k=1,nz-1
            do j=1,ny-2
            do i=1,nx-2
            pertV = dv((k-1)*(nx-2)*(ny-2)+(j-1)*(nx-2)+i)
            if (pertV.ge.0.500) pertV=0.500
            if (pertV.le.-0.500) pertV=-0.500
            if (abs(pertV)<1e-5) pertV=0.0
            dv((k-1)*(nx-2)*(ny-2)+(j-1)*(nx-2)+i) = pertV
            vsf(i+1,j+1,k)=vsf(i+1,j+1,k)+dv((k-1)*(nx-2)*(ny-2)+(j-1)*(nx-2)+i)

            if(vsf(i+1,j+1,k).lt.Minvel) vsf(i+1,j+1,k)=Minvel
            if(vsf(i+1,j+1,k).gt.Maxvel) vsf(i+1,j+1,k)=Maxvel
            enddo
            enddo
            enddo

        else
            gcf=0
            gsf=0
            do k=1,nz-1
            do j=1,ny-2
            do i=1,nx-2
            gcf(i,j,k)=dv((k-1)*(nx-2)*(ny-2)+(j-1)*(nx-2)+i)
            gsf(i,j,k)=dv(maxvp+(k-1)*(nx-2)*(ny-2)+(j-1)*(nx-2)+i)
            enddo
            enddo
            enddo
        endif
        !----------------------------------------------------------------------!
        ! INVERSION RESULT
        if (iso_inv)then
            write(6,'(a,3f10.4)')  '  min  max and abs mean  dVs(km/s)',&
            minval(dv(1:maxvp)),maxval(dv(1:maxvp)),sum(abs(dv(1:maxvp)))/maxvp
            write(66,'(a,3f10.4)') '  min  max and abs mean dVs(km/s) ',&
            minval(dv(1:maxvp)),maxval(dv(1:maxvp)),sum(abs(dv(1:maxvp)))/maxvp
            do k=1,nz-1
            VariVs=sum(abs(dv((k-1)*(nx-2)*(ny-2)+1:k*(nx-2)*(ny-2) )))/((nx-2)*(ny-2))
            write(66,'(a,f4.1,a,f4.1,a,f10.4)') '  Depth= ',depz(k),' - ',depz(k+1),&
            ' km  Abs Mean Variation (km/s) Vs',VariVs
            write(6,'(a,f4.1,a,f4.1,a,f10.4)')  '  Depth= ',depz(k),' - ',depz(k+1),&
            ' km  Abs Mean Variation (km/s) Vs',VariVs
            enddo
       else
            write(6 ,'(a,3f10.4)') '  min  max and abs mean  Gc/L (%) ',&
            minval(dv(1:maxvp))*100, maxval(dv(1:maxvp))*100,&
            sum(abs(dv(1:maxvp)))/maxvp*100
            write(6 ,'(a,3f10.4)') '  min  max and abs mean  Gs/L (%) ',&
            minval(dv(maxvp+1:maxvp+maxvp))*100,maxval(dv(maxvp+1:maxvp+maxvp))*100,&
            sum(abs(dv(maxvp+1:maxvp+maxvp)))/maxvp*100
            write(66,'(a,3f10.4)') '  min  max and abs mean Gc/L (%)   ',&
            minval(dv(1:maxvp))*100,maxval(dv(1:maxvp))*100,&
            sum(abs(dv(1:maxvp)))/maxvp*100
            write(66,'(a,3f10.4)') '  min  max and abs mean Gs/L (%)   ',&
            minval(dv(maxvp+1:maxvp+maxvp))*100,maxval(dv(maxvp+1:maxvp+maxvp))*100,&
            sum(abs(dv(maxvp+1:maxvp+maxvp)))/maxvp*100
            do k=1, nz-1
                VariGc=sum(abs(gcf(1:nx-2,1:ny-2,k)))/((nx-2)*(ny-2))
                VariGs=sum(abs(gsf(1:nx-2,1:ny-2,k)))/((nx-2)*(ny-2))
                write(66,'(a, f4.1, a, f4.1, a, 2f10.3)') '  Depth= ',depz(k),' - ',depz(k+1),' km  Abs Mean Variation (%)  Gc &
                 Gs', VariGc*100, VariGs*100
                  write(6,'(a,f4.1,a,f4.1,a,2f10.3)')     '  Depth= ',depz(k),' - ',depz(k+1),' km  Abs Mean Variation (%)  Gc &
                 Gs', VariGc*100, VariGs*100
            enddo
        endif
        !----------------------------------------------------------------------!
        ! Calculate ||Lm||2
        Mnorm2 = 0
        MwNorm2 = 0
        if (iso_inv) then
            weight=weightVs
        else
            weight=weightGcs
        endif
        if (weight.NE.0.0)then
            count3=nar-nar1
            call Calmodel2Norm(nar1, nar, maxvp, count3, rw, col, dv, weight, Mnorm2, MwNorm2)
        endif
        !----------------------------------------------------------------------!
        ! Calculate ||W(Gm-d)||2
        ! fist forward calculate the traveltime.
        ! Tdata: inversion used data: tobs- tref(iso)
        ! Calculate deltaT=deltaTvs+deltaTaa
        ! Here restT=deltaT_in-deltaT_out---use the old GGc GGs
        resbst=0
        res2Norm=0
        resNSigma2Norm=0
        if (iso_inv) then
            call CalVsReslNorm(maxvp,dall,GVs,dv, datweight, Tdata, fwdTvs, resbst, res2Norm, resNSigma2Norm, PreRes)
        else
            fwdTaa=0
            call  CalGcsReslNorm(maxvp,dall,GGc,GGs,dv, datweight, Tdata, fwdTaa, resbst, res2Norm, resNSigma2Norm, PreRes)
            ! update T_AA.
            RefTaa=0
            forall(i=1:dall)
                RefTaa(i)=fwdTaa(i)
            end forall
        endif
        !-----------------------------------------------------------------------!
        ! Statistic for the inversion space .
        write(*,'(a,f12.1)') '  RESIDUAL ||W(Gm-d)||^2: ', res2Norm
        write(*,'(a,f12.1)') '  RESIDUAL ||(Gm-d)||^2:  ' , resNSigma2Norm
        write(*,'(a,f12.1)') '  MODEL ||Lm||^2 2NORM:   ', Mnorm2
        write(6,'(a,f12.1)') '  MODEL ||wLm||^2 2NORM:  ', MwNorm2
        write(66,'(a)')'  '
        write(66,'(a,f12.1)') '  RESIDUAL ||W(Gm-d)||^2: ', res2Norm
        write(66,'(a,f12.1)') '  RESIDUAL ||(Gm-d)||^2:  ' , resNSigma2Norm
        write(66,'(a,f12.1)') '  MODEL ||Lm||^2 2NORM:   ', Mnorm2
        write(66,'(a,f12.1)') '  MODEL ||wLm||^2 2NORM:  ', MwNorm2
        !----------------------------------------------------------------------!
        !  Residual Traveltime Analsysi
        !  1.  forward calculate the traveltime.
        !  2.  forward calculate the phase velocity map.
        !  dsyn: ref-iso traveltime from G-matrix based on vsf model.
        !  Tdata: inversion used data: tobs- tref(iso)
        !  fwdTaa: Taa from inversion mode. (from: CalGcsReslNorm)
        !  fwdTvs: dT from G*dv (from: CalGcsReslNorm)
        !  resbst: residual, without weight(res2Norm with weight)
        !  Here restT=T_obs-T_forward
        ! write out whole residual for whole travel time
        filename = 'Traveltime_statis_'//TRIM(id)//'th.dat'
        open(88,file=TRIM(filename))

        if (iso_inv) then
            write(88,'(7a)')'   Dist(km)   T_obs(s)  T_ref_iso   Res(in)   T_aa(fit)   Res(out)'
            do i=1,dall
                write(88,'(3f10.3, 3e12.3)') dist(i), obst(i), dsyn(i), Tdata(i), fwdTaa(i), resbst(i)
            enddo
        else
            write(88,'(7a)')'          Dist(km)       T_obs(s)        T_ref-iso        T_ref_aa        T_ref_All        Res(in)   &
            dT(fit)        Res(out)'
            do i=1,dall
                write(88,'(5f10.4, 3e12.3)') dist(i), obst(i), dsyn(i), RefTaa(i), Tref(i), Tdata(i), fwdTvs(i), resbst(i)
            enddo
        endif
        close(88)
        !----------------------------------------------------------------------!
        ! Statistic for the  data residual.
        write(66,'(a)')'  -----------------------------------------------------------'
        mean = sum(resbst(1:dall))/dall
        meanAbs=sum(abs(resbst(1:dall)))/dall
        std_devs = sqrt(sum((resbst(1:dall)-mean)**2)/dall)

        if (iso_inv) then
            write(6 ,'(a)') '  ISO-Inversion, Data fit: (Tobs - T_ref-iso - T_ref-aa)'
            write(66,'(a)') '  ISO-Inversion, Data fit: (Tobs - T_ref-iso - T_ref-aa)'
        else
            write(6 ,'(a)') '  Aniso-Inversion, Data fit: (Tobs - T_ref-iso)'
            write(66,'(a)') '  Aniso-Inversion, Data fit: (Tobs - T_ref-iso)'
        endif

        write(6 ,'(a, f6.1)')'  Residual Leaving (Res_new/Res_org) (%)', PreRes*100
        write(66,'(a, f6.1)')'  Residual Leaving (Res_new/Res_org) (%)', PreRes*100
        write(6 ,'(a,f12.4,a,f10.2,a,f10.2,a)') '  After Inversion: abs mean, std_devs and RMS of Res: ', &
        meanAbs,'s ', std_devs,'s ', dnrm2(dall,resbst,1)/sqrt(real(dall)),'s'
        write(66,'(a,f12.4,a,f10.2,a,f10.2,a)') '  After Inversion: mean, std_devs and RMS of Res: ', &
        meanAbs,'s ', std_devs,'s ', dnrm2(dall,resbst,1)/sqrt(real(dall)),'s'

        mean=sum(abs(RefTaa(1:dall)))/dall
        write(66,'(a,f12.4,a)')'  ABS Mean Taa:',mean,'s'
        !----------------------------------------------------------------------!
        if (iso_mod) then
        write(34,*)',OUTPUT S VELOCITY AT ITERATION',iter
        do k=1,nz
        do j=1,ny
        write(34,'(100f7.3)') (vsf(i,j,k),i=1,nx)
        enddo
        enddo
        write(34,*)',OUTPUT DWS AT ITERATION',iter
        do k=1,nz-1
        do j=2,ny-1
        write(34,'(100f10.3)') (norm((k-1)*(ny-2)*(nx-2)+(j-2)*(nx-2)+i-1),i=2,nx-1)
        enddo
        enddo
        endif
        !----------------------------------------------------------------------!
        write(66,'(a)') ' '
        write(6 ,'(a)') '  '

        enddo ! iteration


        ! if (iso_inv) then
        filename = 'MOD_Ref'
        open(11, file=filename)
        do k=1,nz
            write(11,'(f5.1)',advance='no') depz(k)
        enddo
        do k = 1,nz
        do j = 1,ny
        do i=1,nx
        if (i.eq.1) then
        write(11,'(/f7.4)',advance='no')vsf(i,j,k)
        else
        write(11,'(f7.4)',advance='no')vsf(i,j,k)
        endif
        enddo
        enddo
        enddo
        close(11)
        ! endif
        !----------------------------------------------------------------------!
        ! output inversion result.
        open(63,file='DSurfTomo.inv')
        open(73,file='Gc_Gs_model.inv')
        call writeVsmodel(nx,ny,nz,gozd,goxd,dvzd,dvxd,depz,vsf,63)
        call writeAzimuthal(nx,ny,nz,gozd,goxd,dvzd,dvxd,depz,gcf,gsf,vsf,73)
        close(63)
        close(73)
        !----------------------------------------------------------------------!
        open(77,file='phaseV_FWD.dat')
        call WTPeriodPhaseV(nx,ny,gozd,goxd,dvzd,dvxd,kmaxRc,tRc,tRcV,77)
        !----------------------------------------------------------------------!
        write(*,'(a)')'  Begin forward calculate period azimuthal A1, A2.'
        open(42,file='period_Azm_tomo.inv',status='replace',action='write')
        call FwdAzimuthalAniMap(nx,ny,nz,maxvp,&
            goxd,gozd,dvxd,dvzd,kmaxRc,tRc,&
           gcf,gsf,Lsen_Gsc,tRcV)
        !----------------------------------------------------------------------!
        ! output result model
        ! note: for the input Vs model is grid model (nz point)
        ! BUT, the inversion kernel and result is layer (nz-1 layer) model
        ! for Gc,Gs  the input and result are both layer model, so the depth I set the lower depth as the output
        ! for Vs, input is grid model, while the inversion result is layered model. For compare withe two Vs models,
        !  I set the mid depth between the point as the depth index, and the real model use the average Vs.
        write(66,*)'  -----------------------------------------------------------'
        write(*,*)  '  Program finishes successfully'
        write(66,*) '  Program finishes successfully'

        write(*,*)  '  Output inverted shear velocity model: Vs_model_Syn.rela  Vs_model_Syn.abs'
        write(66,*) '  Output inverted shear velocity model: Vs_model_Syn.rela  Vs_model_Syn.abs'

        endT=OMP_get_wtime()
        write(* ,'(a, f13.1, a)') '   All time cost= ',endT-startT,"s"
        write(66,'(a, f13.1, a)') '   All time cost= ',endT-startT,"s"

        close(10)   ! surfaniso.in
        close(nout) ! close lsmr.txt
        close(66)   ! close surf_tomo.log
        close(34)   ! IterVel.out
        deallocate(obst)
        deallocate(dsyn)
        deallocate(dist)
        deallocate(pvall)
        deallocate(depz)
        deallocate(norm)
        deallocate(scxf,sczf)
        deallocate(rcxf,rczf)
        deallocate(wavetype,igrt,nrc1)
        deallocate(nsrc1,periods)
        deallocate(rw)
        deallocate(iw,col)
        deallocate(cbst)
        deallocate(dv)
        deallocate(vsf)
        deallocate(sigmaT,Tdata,resbst,fwdT,resSigma,resbst_iso)
        deallocate(fwdTvs,fwdTaa)
        deallocate(RefTaa,Tref)
        deallocate(GVs,GGs,GGc,Lsen_Gsc)

        deallocate(gcf,gsf)
        if(kmaxRc.gt.0) then
            deallocate(tRc)
        endif
        deallocate(tRcV)
end program


subroutine writeVsmodel(nx, ny, nz, gozd, goxd, dvzd, dvxd, depz, vsf, Idout)
        integer nx,ny,nz
        real goxd,gozd
        real dvxd,dvzd
        real depz(nz)
        ! real vsAbs(nx-2,ny-2,nz-1), vsRela(nx-2,ny-2,nz-1)
        integer Idout
        real:: vsf(nx,ny,nz)
        integer:: k,j,i
        real :: vsref
        ! Because the (gozd,goxd) point is NE point of the inversion region.---> NE move 1 point.
        do k=1,nz
              do j=1,ny
                    do i=1,nx
                        write(Idout,'(5f8.4)') gozd+(j-2)*dvzd,goxd-(i-2)*dvxd,depz(k),vsf(i,j,k)
                    enddo
                enddo
            enddo
end subroutine writeVsmodel


subroutine writeAzimuthal(nx, ny, nz, gozd, goxd, dvzd, dvxd, depz, Gc, Gs, vsf, Idout)
        integer nx,ny,nz
        real goxd,gozd
        real dvxd,dvzd
        real depz(nz)
        real Gc(nx-2,ny-2,nz-1),Gs(nx-2,ny-2,nz-1)
        real:: vsf(nx,ny,nz)
        integer Idout
        integer:: k,j,i
        real cosTmp,sinTmp
        real vsref
        real*8 :: pi=3.1415926535898
        do k=1,nz-1
            do j=1,ny-2
                do i=1,nx-2
                    cosTmp=Gc(i,j,k)
                    sinTmp=Gs(i,j,k)
                    AzimAmp=0.5*sqrt(cosTmp**2+sinTmp**2)
                    AzimAng=atan2(sinTmp,cosTmp)/pi*180
                    if (AzimAng.LT.0.0) AzimAng=AzimAng+360
                    AzimAng=0.5*AzimAng
                    ! format: lon lat  depth(lower) Vs(mid-depth)  Angle  Amp(%/100) Gc/L(%)  Gs/L(%)
                    vsref=(vsf(i+1,j+1,k)+vsf(i+1,j+1,k+1))/2
                    write(Idout,'(8f10.4)') gozd+(j-1)*dvzd,goxd-(i-1)*dvxd,depz(k+1),vsref,AzimAng,AzimAmp,&
                           Gc(i,j,k)*100,Gs(i,j,k)*100
                enddo
            enddo
        enddo
end subroutine writeAzimuthal

subroutine WTPeriodPhaseV(nx,ny,gozd,goxd,dvzd,dvxd,kmaxRc,tRc,pvRc,Idout)
        implicit none
        integer nx,ny
        real goxd,gozd
        real dvxd,dvzd
        integer kmaxRc
        real*8 tRc(kmaxRc)
        real*8 pvRc((nx-2)*(ny-2),kmaxRc)
        integer Idout
        integer:: tt,k,jj,ii
        ! note:  pvRc((nx-2)*(ny-2),kmaxRc) ----different pvRc in
        do tt=1,kmaxRc
            do jj=1,ny-2
                do ii=1,nx-2
                    write(Idout,'(5f10.4)') gozd+(jj-1)*dvzd,goxd-(ii-1)*dvxd,tRc(tt),pvRc((jj-1)*(nx-2)+ii,tt)
                enddo
            enddo
        enddo
        close(Idout)
end subroutine WTPeriodPhaseV

subroutine CalRmax(nz, depz, minthk0, rmax)
        implicit none
        integer nz
        real depz(nz)
        real minthk0, minthk
        integer rmax
        integer k,i
        integer NL
        parameter (NL=200)
        integer nsublay(NL)
        real thk
        rmax=0
        do i=1, nz-1
            thk = depz(i+1)-depz(i)
            minthk = thk/minthk0
            nsublay(i) = int((thk+1.0e-4)/minthk) + 1
        enddo
        rmax=sum(nsublay(1:nz-1))
end subroutine CalRmax
