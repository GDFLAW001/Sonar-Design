#!/usr/bin/env julia
using Gtk, Gtk.ShortNames

win = Window("Angle Finder 3000",500,500)
v = Box(:v)
b = Button("Start Plotting")
b2 = Button("Stop Plotting")
b3 = Button("Pause Plotting")
push!(win, v)
push!(v,b3)
push!(v, b2)
push!(v, b)
set_gtk_property!(v, :expand, b3, true)
set_gtk_property!(v, :expand, b2, true)
set_gtk_property!(v, :expand, b, true)

showall(win)

function start_plot()
    
    return nothing
end

function pause_plot()
    
    return nothing
end

function stop_plot()
    
    return nothing
end

signal_connect(x -> start_plot(), b, "clicked")
signal_connect(x -> stop_plot(), b2, "clicked")
signal_connect(x -> pause_plot(), b3, "clicked")

if !isinteractive()
    c = Condition()
    signal_connect(win, :destroy) do widget
        notify(c)
    end
    wait(c)
end
