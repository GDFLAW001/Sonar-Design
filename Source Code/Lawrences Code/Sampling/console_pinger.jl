# Basic serial console.
# Data is read from a serial device and lines (but not individual keypresses)
# are written to the device asynchronously.

using LibSerialPort
using PyPlot

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
        list_ports()
        return
    end

    # Open a serial connection to the microcontroller
    mcu = open(string("/dev/ttyACM", args[1]), 9600)

    serial_loop(mcu)
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

    ion()
    fig = figure()
    for n in 1:10
        i =1 #data samples recieved

        # Clear buffer
        while (bytesavailable(sp)>0)
            read(sp,UInt8)
        end

        # Transmit and Sample command
        write(sp,"t") 

        while bytesavailable(sp) < 1
            continue # wait for a response    
        end  
        sleep(0.05) # This extra delay helps with reliability - it gives the micro time to send all it needs to

        # Get timing information
        time = parse(Int,readline(sp)) 
        time2 = parse(Int,readline(sp)) 

        #Grab samples
        write(sp,"p") # Print DMA buffer

        while bytesavailable(sp) < 1   
            continue # wait for a response    
        end 

        sleep(0.05)
        while true
            if bytesavailable(sp) < 3
                sleep(0.080) # Wait and check again
                if bytesavailable(sp) < 2
                    break
                end
            end
            
            try 
                x_rx[i]=(parse(Int32,(readline(sp))))&0b00000000000000001111111111111111
            catch
                println("error")
                continue;
            end
            
            #println(i," ",x_rx[i])
            i += 1    
        end

        println("Number of samples received ", i-1)

        # Convert ADC output to voltage
        v_rx=(x_rx*(3.3/(2^12)))

        #Plot
        cla()
        plot(t[1:29200],v_rx,".-")   
    end

    print("Done")
    
end

console(ARGS...)