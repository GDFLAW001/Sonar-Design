win = GtkWindow("A new window")
g = GtkGrid()
a = GtkEntry()  # a widget for entering text
set_gtk_property!(a, :text, "This is Gtk!")
b = GtkCheckButton("Check me!")
c = GtkScale(false, 0:10)     # a slider
space = GtkLabel("")

# Now let's place these graphical elements into the Grid:
g[2,2] = a    # Cartesian coordinates, g[x,y]
g[3,2] = b
g[4,2] = space
g[1:2,3] = c  # spans both columns
set_gtk_property!(g, :column_homogeneous, true)
set_gtk_property!(g, :column_spacing, 15)  # introduce a 15-pixel gap between columns
push!(win, g)
showall(win)