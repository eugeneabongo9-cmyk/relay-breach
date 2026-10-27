# Postmortem

The slice is one room script plus pure rules because a second framework would not have made the tether easier to test. Building meshes in code kept the repo free of imported binaries and made restarts easy to count.

What I would change next, in order:

1. Play the Linux export on a real GPU and replace the UNVERIFIED frame row with a capture.
2. Give pursuers a short nav mesh or ray steer so corners are less sticky than a timed sidestep.
3. Let the web page unlock audio on the same gesture that starts the run. Today the game document may stay silent until a click lands inside it.
4. Drop the test script out of the release pack so the pck stays smaller.

I would not add a second link, crafting, or procedural rooms until the four authored bays are boring on purpose.
