# Basic serial console.
# Data is read from a serial device and lines (but not individual keypresses)
# are written to the device asynchronously.

@time using LibSerialPort
@time using PyPlot
@time using FFTW
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
        list_serialports()
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

function sample (sp::SerialPort)
    # Clear buffer
    while (bytesavailable(sp)>0)
        read(sp,UInt8)
    end

    # Transmit and Sample command
    write(sp,"t") 

    while bytesavailable(sp) < 1
        continue # wait for a response    
    end  
    sleep(0.005) # This extra delay helps with reliability - it gives the micro time to send all it needs to

    # Get timing information
    time = parse(Int,readline(sp)) 
    time2 = parse(Int,readline(sp)) 

    #Grab samples
    write(sp,"p") # Print DMA buffer

    while bytesavailable(sp) < 1   
        continue # wait for a response    
    end 

    sleep(0.005)
    @time begin
        while true
            if bytesavailable(sp) < 3
                sleep(0.0001) # Wait and check again
                if bytesavailable(sp) < 1
                    break
                end
            end

            #println(i)
            line = readline(sp)
            #println(line)
            if (length(line)>4)
                continue;
            else
                x_rx[i]=(parse(Int16,line))
            end
            
            #println(i," ",x_rx[i])
            i += 1    
        end
        #code
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
    
    B = 0.3*ω0/(2π) # filter bandwidth in Hz
    
    # In the sampled frequency domain, position two rect() 
    # i.e. centred on ω0 rad/s and on 2pi/Δt-ω0 rad/s.
    
    H = rect((ω .- ω0)/(2*π*B)) + rect( (ω .+ (ω0 .- 2*π/Δt) )/(2*π*B) )
    
    Y = CHIRP .* H[1:29200]

    H1 = conj(Y);
    

    ion()
    fig = figure(figsize=(10, 8))
    # ax = gca()
    # ax[:set_ylim]([0,3.3])
    while true
        i =1 #data samples recieved
        
        sample(sp,x_rx);

        println(i);

        # Convert ADC output to voltage
        v_rx=(x_rx*(3.3/(2^12)))
        V_RX = fft(v_rx)
        V_MF = H1.*V_RX;
        v_mf = ifft(V_MF);
        v_mf=v_mf.*r[1:29200].*r[1:29200]

        largest_val = 0;
        peak_time = 0;
        for n = 1:length(v_mf)
            if v_mf[n]>largest_val[n]
                largest_val=v_mf[n]
                peak_time = t[n]
            end
        end

        largest_val_2 = 0;
        peak_time_2 = 0;
        for n = 1:length(v_mf2)
            if v_mf2[n]>largest_val_2[n]
                largest_val_2=v_mf2[n]
                peak_time_2 = t[n]
            end
        end

        k=1;
        lambda = (2*pi*c)/ω;
        d=2*lambda
        delta_psi = angle(v_mf .* conj(v_mf2))
        angle = asin((lambda*(delta_psi + k*2*pi))/(2*pi*d));
        




        #Plot
        cla()
        plot(r[1:25000],v_mf[1:25000],"-")  
        ylim([-200,200])

        
        println("plotted") 
    end

    print("Done")
    
end

#console(ARGS...)