# Basic serial console.
# Data is read from a serial device and lines (but not individual keypresses)
# are written to the device asynchronously.
@time using PyPlot
@time using FFTW
@time using SerialPorts
include("chirp.jl");

function serial_loop(sp::SerialPort)
    input_line = ""

    println("Starting I/O loop. Press ESC [return] to quit")

    while true
        # Poll for new data without blocking
        @async input_line = readline(keep=true)

        occursin("\e", input_line) && exit()

        # Send user input to device
        if endswith(input_line, '\n')
            if (chomp(input_line)=="start")

                println("started")
                continuousplot(sp)
            end
            input_line="";
        end

        # Give the queued tasks a chance to run
        sleep(0.1)
    end
end

function console(args...)

    
    if length(args) != 1
        show(list_serialports())
        return
    end

    # Open a serial connection to the microcontroller
    mcu = SerialPort(string("/dev/ttyACM", args[1]), 9600)

    serial_loop(mcu)
end

function rect(t)
    N = length(t)
    x = zeros(N)  # create array of zeros
    for n=1:N
        abs_t = abs(t[n]);    
        if abs_t > 0.5 
            x[n]=0.0
        elseif abs_t < 0.5 
            x[n]=1.0
        else
            x[n]=0.5     # case of t[n] = 0.5 (rising edge) or -0.5 (falling edge) 
        end
    end
    return x

end

function continuousplot(sp::SerialPort)
    v_rx=(x_rx*(3.3/(2^12)))

    #Setup variables
    IgnoreTime=0.01

    #Time
    S=29200 #Number of samples expected
    CS=Int(floor((S+(500000*IgnoreTime)))) #Number of samples with compensation
    c = 343 # Speed of sound in air in m/s
    timeSample=20/343 +IgnoreTime # Amount of time sampled for
    dt=timeSample/CS
    t=collect(0:dt:timeSample)[1:CS] # t=0:dt:t_max defines a “range”.
    r = c*t/2;

    Lower=150
    Upper=2100
    
    chirp=zeros(CS)
       
    i =0
    for n = 1:CS
        chirp[n]=1.65
        if n>(Lower-1)&& n < (Upper+1)
            chirp[1+i]=v_rx[n]
            i+=1
        end
    end

    N = length(t);
    Δf = 1/(N*dt) # spacing in frequency domain
    #create array of freq values stored in f_axis. First element maps to 0Hz
    if mod(N,2)==0 # case N even
        f_axis = (-N/2:N/2-1)*Δf;
        else # case N odd
        f_axis = (-(N-1)/2 : (N-1)/2)*Δf;
    end

    CHIRP = fft(chirp)

    Δt=dt
    Δω = 2*pi/(N*Δt)   # Sample spacing in freq domain in rad/s
    
    ω = 0:Δω:(N-1)*Δω
    f = ω/(2*π)
        
    ω0=41000*2π
    
    B = 3000 # filter bandwidth in Hz
    
    H = rect((ω .- ω0)/(2*π*B)) + rect( (ω .+ (ω0 .- 2*π/Δt) )/(2*π*B) )

    Y = CHIRP 
    y = ifft(Y)
    

    MF = conj(Y);

    # figure()
    # plot(y)    
    # show()

    ion()
    fig = figure(figsize=(10, 8))
    fig2 = figure(figsize=(10, 8))
    # ax = gca()
    # ax[:set_ylim]([0,3.3])
    while true
        x_rx1=zeros(Int16,CS) # Samples values recieved
        x_rx2=zeros(Int16,CS) # Samples values recieved
        #data=Array{Union{Nothing,String}}(nothing,S)
        data=""

        # Clear buffer
        while (bytesavailable(sp)>0)
            readavailable(sp)
        end

        # Transmit and Sample command
        write(sp,"t") 

        while bytesavailable(sp) < 1
            continue # wait for a response    
        end  
        sleep(0.05) # This extra delay helps with reliability - it gives the micro time to send all it needs to

        timeString=readavailable(sp)
        timeArray=split(timeString,"\n")

        # Get timing information
        time = parse(UInt16,timeArray[1])
        timeSeconds = time*10^-6
        # println("Time taken to sample ",timeSeconds, " s")

        timeBetweenTransmitAndRecieve = parse(UInt16,timeArray[2])
        # println("Time between transmitting and receiving ",timeBetweenTransmitAndRecieve, " us")

        # Clear buffer
        while (bytesavailable(sp)>0)
            readavailable(sp)
        end

        #Grab samples
        write(sp,"p") # Print DMA buffer

        while bytesavailable(sp) < 1   
            continue # wait for a response    
        end 

        sleep(0.05)

        while true
            if bytesavailable(sp) < 1
                sleep(0.010) # Wait and check again
                if bytesavailable(sp) < 1
                    println("Finished Reading")
                    break
                end
            end
            data=string(data,readavailable(sp))
            i += 1 
        end

        samples = split(data,"\r\n")
        println("Number of samples received ", size(samples))

        for n in 1:S
            #print(x_rx[n])
            x_rx1[n]=parse(UInt16,samples[n])
        end
        for n in S:CS
            x_rx1[n]=2048
        end

        # Convert ADC output to voltage
        v_rx1=(x_rx1.*(3.3/(2^12)))

        data=""

        #Grab samples
        write(sp,"o") # Print DMA buffer
        
        while bytesavailable(sp) < 1   
            continue # wait for a response    
        end 
        
        sleep(0.05)
        
        while true
            if bytesavailable(sp) < 1
                sleep(0.010) # Wait and check again
                if bytesavailable(sp) < 1
                    println("Finished Reading")
                    break
                end
            end
            data=string(data,readavailable(sp))
            i += 1 
        end
        
        samples = split(data,"\r\n")
        println("Number of samples received ", size(samples))
        #print(samples)
        
        for n in 1:S
            #print(x_rx[n])
            x_rx2[n]=parse(UInt16,samples[n])
        end
        for n in S:CS
            x_rx2[n]=2048
        end
        
        # Convert ADC output to voltage
        v_rx2=(x_rx2.*(3.3/(2^12)))

        # Baseband singal 1
        V_RX1 = fft(v_rx1)
        V_RX1 = V_RX1 .* H        
        V_MF1 = MF[1:CS].*V_RX1[1:CS];
        v_mf1 = ifft(V_MF1[1:CS]);        
        v_mf1=v_mf1.*r[1:CS].*r[1:CS]

        ω0=41000*2π * 0.985

        V_ANAL1 = 2*V_MF1; # make a copy and double the values
        N = length(V_MF1);
        if mod(N,2)==0 # case N even
        neg_freq_range = Int(N/2):N; # Define range of "neg-freq" components
        else # case N odd
        neg_freq_range = Int((N+1)/2):N;
        end
        V_ANAL1[neg_freq_range] .= 0; # Zero out neg components in 2nd half of array.
        v_anal1 = ifft(V_ANAL1);

        j=im; # Assign j as sqrt(-1) (“im” in julia)
        v_bb1 = v_anal1.*exp.(-j*ω0*t)
        v_bb1=v_bb1.*r.*r

        # Baseband singal 2
        V_RX2 = fft(v_rx2)
        V_RX2 = V_RX2 .* H        
        V_MF2 = MF[1:CS].*V_RX2[1:CS];
        v_mf2 = ifft(V_MF2[1:CS]);        
        v_mf2=v_mf2.*r[1:CS].*r[1:CS]

        V_ANAL2 = 2*V_MF2; # make a copy and double the values
        N = length(V_MF2);
        if mod(N,2)==0 # case N even
        neg_freq_range = Int(N/2):N; # Define range of "neg-freq" components
        else # case N odd
        neg_freq_range = Int((N+1)/2):N;
        end
        V_ANAL2[neg_freq_range] .= 0; # Zero out neg components in 2nd half of array.
        v_anal2 = ifft(V_ANAL2);

        v_bb2 = v_anal2.*exp.(-j*ω0*t);
        v_bb2=v_bb2.*r.*r

        # Get angle
        delta_psi = angle.(v_bb1 .* conj(v_bb2))
        
        lambda = (2*pi*c)/ω0;
        d=0.02

        k=0;
        ang0 = asin.((lambda*(delta_psi .+ k*2*pi))/(2*pi*d)) ;

        k=1;
        ang1 = asin.((lambda*(delta_psi .+ k*2*pi))/(2*pi*d));

        k=-1;
        angm1 = asin.((lambda*(delta_psi .+ k*2*pi))/(2*pi*d));

        x0=r.*cos.(ang0)
        y0=r.*sin.(ang0)

        x1=r.*cos.(ang1)
        y1=r.*sin.(ang1)

        xmin1=r.*cos.(angm1)
        ymin1=r.*sin.(angm1)


        figure(1)
        subplot(411)
        cla()  
        plot(r[1:S],v_rx1[1:S])          
        ylim([0,3.3]) 

        subplot(412)
        cla()   
        plot(r[1:S],v_rx2[1:S])        
        ylim([0,3.3]) 

        
        subplot(413)
        cla()
        plot(r[1:S],abs.(v_bb1[1:S]))     
        plot(r[1:S],abs.(v_bb2[1:S]))  
        ylim([0,5000])
        show() 

        subplot(414)
        cla()
        plot(x0[1:S],y0[1:S],".")
        plot(x1[1:S],y1[1:S],".")
        plot(xmin1[1:S],ymin1[1:S],".")
        ylim([-5,5])
        show()

        # Find targets
        targets=zeros(Int16,S) # Samples values recieved
        #targets=Array{Any}(undef,S)     
        
        threshold = 1000
        for n in 2:S-1
            # Find increasing and then decreasing values
            prev0=abs.(v_bb1[n-1])
            current0 = abs.(v_bb1[n])
            next0= abs.(v_bb1[n+1])
            current1 = abs.(v_bb2[n])
            if ((prev0<current0) && (next0<current0) && (current0>threshold || current1>threshold))
                targets[n]=Int16(floor(current0))
                #x[n]=null
            else
                targets[n]=0
                y0[n]=10
                y1[n]=10
                ymin1[n]=10
            end
        end

        figure(2)
        cla()
        plot(x0[1:S],y0[1:S],".")
        plot(x1[1:S],y1[1:S],".")
        plot(xmin1[1:S],ymin1[1:S],".")
        #axis("square")
        ylim([-9,9])
        xlim([0,10])
        show() 
        
        
        println(size(v_rx))
        println(size(t))
    end

    print("Done")
    
end

console(ARGS...)