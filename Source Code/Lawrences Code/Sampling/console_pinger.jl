# Basic serial console.
# Data is read from a serial device and lines (but not individual keypresses)
# are written to the device asynchronously.

using SerialPorts
using PyPlot
using FFTW
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

function sample(sp::SerialPort,receiver)
    IgnoreTime=0.01

    #Time
    S=29200 #Number of samples expected
    CS=Int(floor((S+(500000*IgnoreTime))))

    x_rx=zeros(Int16,CS) # Samples values recieved
    #data=Array{Union{Nothing,String}}(nothing,S)
    data=""

    # Clear buffer
    while (bytesavailable(sp)>0)
        readavailable(sp)
    end

    # Transmit and Sample command
    write(sp,receiver) 

    while bytesavailable(sp) < 1
        continue # wait for a response    
    end  
    sleep(0.05) # This extra delay helps with reliability - it gives the micro time to send all it needs to

    timeString=readavailable(sp)
    timeArray=split(timeString,"\n")

    # Get timing information
    time = parse(UInt16,timeArray[1])
    timeSeconds = time*10^-6
    #println("Time taken to sample ",timeSeconds, " s")

    timeBetweenTransmitAndRecieve = parse(UInt16,timeArray[2])
    #println("Time between transmitting and receiving ",timeBetweenTransmitAndRecieve, " us")

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
        #i += 1 
    end

    samples = split(data,"\r\n")
    #println("Number of samples received ", size(samples))

    for n in 1:S
        x_rx[n]=parse(UInt16,samples[n])
    end
    for n in S:CS
        x_rx[n]=2048
    end

    return x_rx;
end

function continuousplot(sp::SerialPort)

    
    match_chirp_v=(match_chirp*(3.3/(2^12)))

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
            chirp[1+i]=match_chirp_v[n]
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

    ion()
    fig = figure(figsize=(10, 8))
    
   
    while true
        x_rx_L = sample(sp,"l");
        sleep(0.005)
        x_rx_R = sample(sp,"r")
        sleep(0.005)

        
        ## _________________PROCESSING FOR RIGHT____________________
        # Convert ADC output to voltage
        x_rx_R=(x_rx_R.*(3.3/(2^12)))
        
        V_RX_R = fft(x_rx_R)
        V_RX_R = V_RX_R .* H

        V_MF_R = MF[1:CS].*V_RX_R[1:CS];
        v_mf_R = ifft(V_MF_R[1:CS]);


        v_mf_R=v_mf_R.*r[1:CS].*r[1:CS]

        V_ANAL_R = 2*V_MF_R; # make a copy and double the values
        N = length(V_MF_R);
        if mod(N,2)==0 # case N even
            neg_freq_range = Int(N/2):N; # Define range of "neg-freq" components
        else # case N odd
            neg_freq_range = Int((N+1)/2):N;
        end
        V_ANAL_R[neg_freq_range] .= 0; # Zero out neg components in 2nd half of array.
        v_anal_R = ifft(V_ANAL_R);

        v_anal_R=v_anal_R.*r.*r

        ## _________________PROCESSING FOR LEFT____________________
        # Convert ADC output to voltage
        x_rx_L=(x_rx_L.*(3.3/(2^12)))

        V_RX_L = fft(x_rx_L)
        V_RX_L = V_RX_L .* H

        V_MF_L = MF[1:CS].*V_RX_L[1:CS];
        v_mf_L = ifft(V_MF_L[1:CS]);


        v_mf_L=v_mf_L.*r[1:CS].*r[1:CS]

        V_ANAL_L = 2*V_MF_L; # make a copy and double the values
        N = length(V_MF_L);
        if mod(N,2)==0 # case N even
            neg_freq_range = Int(N/2):N; # Define range of "neg-freq" components
        else # case N odd
            neg_freq_range = Int((N+1)/2):N;
        end
        V_ANAL_L[neg_freq_range] .= 0; # Zero out neg components in 2nd half of array.
        v_anal_L = ifft(V_ANAL_L);

        v_anal_L=v_anal_L.*r.*r

        largest_val_L = 0;
        peak_time_L = 0;
        for n = 1:S
            if abs(v_anal_L[n])>abs(largest_val_L)
                largest_val_L=v_anal_L[n]
                peak_time_L = t[n]
            end
        end

        largest_val_R = 0;
        peak_time_R = 0;
        for n = 1:S
            if abs(v_anal_R[n])>abs(largest_val_R)
                largest_val_R=v_anal_R[n]
                peak_time_R = t[n]
            end
        end

        k=1;
        lambda = (2*pi*c)/ω0;
        d=2.125*lambda
        delta_psi = angle(largest_val_R .* conj(largest_val_L))
        ang = asin((lambda*(delta_psi + k*2*pi))/(2*pi*d));

        println(string("time to peak LEFT: ", peak_time_L));
        println(string("time to peak RIGHT: ", peak_time_R));
        println(ang*(180/pi))

        ang_array = ones(120)
        ang_array=ang_array.*-1
        ang_array[Int(round(ang*(180/pi)) + 60)] = 1

        subplot(511)
        cla()   
        plot(r[1:S],abs.(v_anal_L[1:S]))          
        ylim([0,1000])

        subplot(512)  
        cla()
        plot(r[1:S],abs.(v_anal_R[1:S]))       
        ylim([0,1000])

        subplot(513)
        cla()
        plot(-60:59,ang_array,".")     
        ylim([0,2])

        subplot(514)
        cla()
        plot(t[1:S],x_rx_L[1:S])     
        ylim([0,3.3])

        subplot(515)
        cla()
        plot(t[1:S],x_rx_R[1:S])     
        ylim([0,3.3])
        show()
     end
    print("Done")    
end

console(ARGS...)