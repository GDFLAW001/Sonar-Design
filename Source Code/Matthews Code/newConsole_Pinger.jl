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
    
    # ax = gca()
    # ax[:set_ylim]([0,3.3])
    while true

        x_rx=zeros(Int16,CS) # Samples values recieved
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
        println("Time taken to sample ",timeSeconds, " s")

        timeBetweenTransmitAndRecieve = parse(UInt16,timeArray[2])
        println("Time between transmitting and receiving ",timeBetweenTransmitAndRecieve, " us")

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
            x_rx[n]=parse(UInt16,samples[n])
        end
        for n in S:CS
            x_rx[n]=2048
        end

        # Convert ADC output to voltage
        v_rx=(x_rx.*(3.3/(2^12)))

        V_RX = fft(v_rx)
        V_RX = V_RX .* H

        V_MF = MF[1:CS].*V_RX[1:CS];
        v_mf = ifft(V_MF[1:CS]);


        v_mf=v_mf.*r[1:CS].*r[1:CS]

        V_ANAL = 2*V_MF; # make a copy and double the values
        N = length(V_MF);
        V_ANAL = 2*V_MF; # make a copy and double the values
        N = length(V_MF);
        if mod(N,2)==0 # case N even
        neg_freq_range = Int(N/2):N; # Define range of "neg-freq" components
        else # case N odd
        neg_freq_range = Int((N+1)/2):N;
        end
        V_ANAL[neg_freq_range] .= 0; # Zero out neg components in 2nd half of array.
        v_anal = ifft(V_ANAL);

        v_anal=v_anal.*r.*r

        cla()     
        subplot(211)
        plot(r[1:S],v_rx[1:S])          
        ylim([0,3.3])
        show() 

        cla()
        subplot(212)
        plot(r[1:S],abs.(v_anal[1:S]))       
        ylim([0,1000])
        show() 
        
        
        println(size(v_rx))
        println(size(t))
    end

    print("Done")
    
end

console(ARGS...)