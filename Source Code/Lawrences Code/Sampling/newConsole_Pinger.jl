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
    #Setup variables
    S=29200 #Number of samples expected
    c = 343 # Speed of sound in air in m/s
   
    x_rx=zeros(Int16,S) # Samples values recieved

    # Create time and distance arrays
    dt=0.05840000000000002/S # Time per sample
    t = collect(0:dt:0.05840000000000002); # t=0:dt:t_max defines a “range”.
    r = c*t/2;

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
    
    ## Pass square wave through a BPF centred on fundamental ω0
    ## The BPF is narrow enough only to allow the fundamental component to pass.
    
    ω0=40000*2π
    
    B = 3000 # filter bandwidth in Hz
    
    # In the sampled frequency domain, position two rect() 
    # i.e. centred on ω0 rad/s and on 2pi/Δt-ω0 rad/s.
    
    H = rect((ω .- ω0)/(2*π*B)) + rect( (ω .+ (ω0 .- 2*π/Δt) )/(2*π*B) )
    
    #Y = CHIRP .* H[1:29200]

    MF = conj(CHIRP);
    

    ion()
    fig = figure(figsize=(10, 8))
    # ax = gca()
    # ax[:set_ylim]([0,3.3])
    while true
        i =1 #data samples recieved

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

        # Create time and distance arrays
        dt=timeSeconds/S # Time per sample
        t = collect(0:dt:timeSeconds); # t=0:dt:t_max defines a “range”.
        r = c*t/2;

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
        @time begin
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
        end

        samples = split(data,"\r\n")
        println("Number of samples received ", size(samples))

        x_rx=zeros(Int16,S)
        for n in 1:S
            x_rx[n]=parse(UInt16,samples[n])
        end

        # Convert ADC output to voltage
        v_rx=(x_rx*(3.3/(2^12)))

        V_RX = fft(v_rx)
        V_RX = V_RX[1:S] .* H[1:S]

        V_MF = MF[1:S].*V_RX[1:S];
        v_mf = ifft(V_MF[1:S]);

        #v_mf=v_mf.*r[1:S].*r[1:S]

        #Plot
        V_ANAL = 2*V_MF; # make a copy and double the values
        N = length(V_MF);

        if mod(N,2)==0 # case N even
        neg_freq_range = Int(N/2):N; # Define range of “neg-freq” components
        else # case N odd
        neg_freq_range = Int((N+1)/2):N;
        end

        V_ANAL[neg_freq_range] .= 0; # Zero out neg components in 2nd half of array.
        v_anal = ifft(V_ANAL);
        V_ANAL = 2*V_MF; # make a copy and double the values
        N = length(V_MF);

        if mod(N,2)==0 # case N even
        neg_freq_range = Int(N/2):N; # Define range of “neg-freq” components
        else # case N odd
        neg_freq_range = Int((N+1)/2):N;
        end

        V_ANAL[neg_freq_range] .= 0; # Zero out neg components in 2nd half of array.
        v_anal = ifft(V_ANAL);
        v_anal=v_anal.*r[1:S].*r[1:S]

        cla()
        plot(r[1:S],abs.(v_anal[1:S]))        
        ylim([-900,900])
        
        println(size(v_rx))
        println(size(t))
    end

    print("Done")
    
end

console(ARGS...)