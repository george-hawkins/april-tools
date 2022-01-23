AprilTools
==========

See Default Cube's video ["Tracking with April Tools In-Depth"](https://youtu.be/g4s4fFmh8DQ).

---

The first issue was the tag - I had the issue described [here](https://github.com/AprilRobotics/apriltag-imgs/issues/4#issuecomment-850044277) that Preview on Mac and Chrome on Linux smoothed the tags.

I used one of the tags generated by @rgov instead:

* For [A4](https://github.com/rgov/apriltag-pdfs/blob/main/tag36h11/a4/200mm/tag36h11_200mm_id000.pdf).
* For [US Letter](https://github.com/rgov/apriltag-pdfs/blob/main/tag36h11/us_letter/200mm/tag36h11_200mm_id000.pdf).

---

For Docker set up, see [here](https://github.com/george-hawkins/docker-cplusplus-coroutines#setup).

---

There's almost nothing to AprilTools (see [`build-apriltools`](build-apriltools)) and the real work is being done by AprilTag (see [`build-apriltag`](build-apriltag)) and OpenCV.

---

To build the Docker image:

    $ docker-compose build

Then to run AprilTools:

    $ docker-compose run hirsute-apriltools apriltools --help
    Usage: apriltools [options] <input files>
      -h | --help                   [ true ]       Show this help   
      -p | --path                   [  ]           Path to the source image sequence   
      -f | --focal-length-mm        [ -1 ]         Focal length in mm   
      -F | --focal-length-pixels    [ -1 ]         Focal length in pixels   
      -w | --sensor-width           [ -1 ]         Camera sensor width in mm   
      -s | --tag-size               [ -1 ]         Tag size (black border, side of the square) in mm   
      -e | --estimate-focal-length  [ false ]      Do not track the marker; instead, estimate the camera focal length in pixels from the provided footage.   
      -q | --quick                  [ false ]      Speed up the process at the expense of reduced accuracy. 

---

Convert footage to frames:

    $ ffmpeg -i my-movie.mov frames/frame-%04d.png

And work out which ones you want to use.

For long clips, extracting all frames becomes a pain. So, see [here](https://github.com/george-hawkins/movie-tracking/blob/master/movie-editing.md), search for "you can't just clip from a given start frame number".

TODO: write script to do all that start frame etc. calculation for you.

---

I kept the range 1478 to 1596. It turns out later that either AprilTools or Blender gets confused by this (it thinks there are 1596 frames with the first 1477 missing).

So renumber things:

    $ mv frames frames-orig
    $ mkdir frames
    $ cd frames-orig
    $ count=1
    $ for frame in frame-*.png
    do
        mv $frame ../frames/frame-$(printf "%04d" $count).png
        let count++
    done

---

Estimate the focal length:

    $ docker-compose run hirsute-apriltools apriltools --path frames --estimate-focal-length

It didn't seem to do a very good job on my footage, it just output:

    Focal length estimation complete. Best guess: -1.00 px.

Which was nothing like the real values, so I used the value I knew were correct.

TODO: I shot a clip where I moved around a tag, I noticed that it failed to guess a focal-length when looking from the bottom of the tag rather than the side. So, I think there's a bug here where e.g. you maybe have to check some y-related value if you fail to find an estimate tied to some x-related value (just guessing wildly).

---

Measure the size of your tag, mine was 144mm on each side.

---

Get it to produce the camera track:

    $ docker-compose run hirsute-apriltools apriltools --focal-length-mm=18 --sensor-width=23.1 --tag-size 144 --path frames
    searching for files...
    Found 119 valid files in the specified directory.
    Processed 1/119 files, out of which 0 blurry (?) and 0 were unusable (no tag found).
    ...
    Processed 119/119 files, out of which 0 blurry (?) and 0 were unusable (no tag found).

    Focal length: 18.00 mm (1496.10 px); sensor width: 23.10 mm
    Camera track saved to: frames/track.txt
    Open Blender and go to file-> import -> Apriltools tracking data (install the plugin if you haven't already) to import the tracking data.

It writes it to `frames/track.txt`.

---

If you look at the `track.txt` file, you'll see:

```
$ head frames/track.txt 
frames/frame-1478.png
18.0000, 23.1000, 144.0000, 0, 0,0,0
1478, 1.6287,0.0313,-0.1006,1.1443,-0.4892,3.2717
```

It turns out that the `apriltags_import.py` importer can only work with absolute paths.

And as the path within the Docker container would be different to the local path, this is unfortunately something you have to resolve by hand.

Just edit the file and add in the full path, so you end up with:

```
$ head frames/track.txt 
/home/joebloggs/my-april-tools-project/frames/frame-1478.png
18.0000, 23.1000, 144.0000, 0, 0,0,0
1478, 1.6287,0.0313,-0.1006,1.1443,-0.4892,3.2717
```

---

Open Blender for _General_.

Install the add-on:

    $ curl -O https://raw.githubusercontent.com/thegoodhen/AprilTools/master/bin/apriltags_import.py

In Blender, go to _Edit / Preference / Add-ons_, click _Install_, find and select the `apriltags_import.py` file and click _Install Add-on_.

After an oddly long pause, it should show up in the list of add-ons. So tick it to enable it.

---

Delete the default cube. Go to _File / Import / Apriltools tracking data_ and import your `track.txt` file.

Things look a little unusual at first, the small plane, you see at the origin actually correspond to your tag.

If you then go to the camera view and press play, you'll see the plane covering the marker as the frames play.

Note: initially, nothing worked because `track.txt` didn't contain an absolute path (see above) and because the frames weren't numbered from 1. Once this was resolved, I didn't have to do anything, the scene length was set correctly (i.e. it wasn't just left at the default 250).

The only thing I had to do was go to _Render_ properties, expand _Color Management_ and set _View Transform_ to _Standard_.

---

The tag looks a little tiny in Blender - but it's tiny in real life - it's got the correct dimensions, i.e. 144x144mm in my case.

---

To make it easier to move and scale things such that the camera and tag maintain the correct relationship.

Make sure nothing is select, then `shift-A` and select _Empty / Plain Axes_. Unselect it, then shift-click the plane, the camera and lastly the empty, press `ctrl-P` (for parenting) and select _Object_.

Now, you can move the tag to a position that better matches where it was in the real world, e.g. rather than being flat on the ground my tag was on a wall about 2m up. So in my case, I went:

* Top-view - `Numpad-7` - selected the empty and then `r90` (and return).
* Side-view - `Numpad-3` - and `r-90` and then `gz2`.

Now, when looking from the front-view, the camera is closest to the viewer and facing the tag that's now facing the viewer and is 2m off the ground.

---

Light levels and closeness to the tag make a huge difference to the quality of the result. I got an unexpected amount of camera jiggle when light levels were low. And similarly bad results when I shot a tag on a wall in good light levels but from further away - I should have printed out a larger tag or moved closer.

TODO: I'm actually surprised at the amount of jiggle in the situation where the light level was low but not terrible and I was close to the tag. Better light levels certainly improved things dramatically but I think it should have done better with the mediocre light levels - I think Blender tracking would not have introduced such jiggle.

TODO: consider trying to print out a very high quality tag. I.e. maximum contrast between black and white, minimum reflectivity, i.e. maximum mattness and on non-warping card.

---

Speed run:

* Start a _General scene_.
* Delete cube and light.
* Import `track.txt` file, `Numpad-0` and check all looks good.
* Select the camera, then _Object Data_ properties, _Viewport Display_ and, if it looks huge, set its size to something reasonable e.g. 0.2m.
* _Render_ properties, _Color Management_, set _Standard_. **TODO**: I think leaving _Filmic_ would make no difference to clip and improve render.
* Choose a frame where the tag A4 sheet is well in shot, zoom in on it. Select tag, `tab` and for each corner in turn, do `g`, `shift-Z` and drag it to the corresponding corner of the A4 sheet.
* Then (with "Import Images as Planes" add-on enabled), import the `saint-cropped.png` image with _Use Alpha_ option unticked (for whatever reason the image otherwise appears semi-transparent even if it has no alpha channel).
* Rotate it with `r90` etc. until it's on top of the tag.
* Then `Numpad-7` and grab its corners and move them so they're slightly outside the tag's corners (so it completely hides the tag in all frames). Easier to do with _Wireframe_ viewport shading.
* Hide or delete the tag.
* Add in the monkey, give it a _Subdivision Surface_ modifier, and _Shade Smooth_. Give it a material with _Transmission_ 1.0 and _Roughness_ 0.1 and _Base Color_ a light reddish pink.
* In _World_ properties, click the _Color_ dot, select _Environment Texture_ and add a HDRI.
* Go to _Shading_ workspace, switch to _Render_ viewport shading. Switch to _World_ data and add in an _Input / Texture Coordinate_ node and a _Vector / Mapping_ node and use them to line up the HDRI with the scene.
* In _Render_ properties, expand _Film_ and tick _Transparent_.
* This [overview](https://youtu.be/7ubTPpIiw3M?t=2184) by Default Cube of compositing (36m 24s into his "Advanced 3D Integration" video) showed me how simple the compositing setup is, so I created it by hand like so...
* Go to the _Compositing_ workspace, tick _Use Nodes_. Add an _Input / Image_ node, select the set of frames (I tried _Movie Clip_ and other things to see if I could automatically pick up the camera background images but I couldn't see how to do this). Add a _Color / Alpha Over_ node. Add an _Output / Viewer_ node if you want to see results in the background. And you end up with the setup below.
* See **Super Important** note below.
* Switch to _Cycles_ rendering (with _GPU Compute_ of course) and tick _Motion Blur_ (it seems to add about 20% to render time).
* Go to _Output_ properties, assuming _Resolution_ and _Frame Rate_ are already good, select an _Output_ directory and leave _File Format_ as PNG (or go for _OpenEXR_ to capture everything). Then `ctrl-F12` to render all frames. Total rendering time was about 80m for 141 images at 1080p.

**Super Important:** _Start Frame_ value in the _Image_ node is 1. This is  not the same as the _Start_ value in the _Background Images_ section of the camera's _Object Data_ properties. So I rendered out the entire thing and only then found out things didn't line up. Initially, I thought the solution was to adjust the nodes _Start Frame_ value to 0 but solution is to **set the _Offset_ to 1**. Perhaps it's always best to do an Eevee render first as a sanity check before committing to Cycles.

**TODO:** I think this mess-up all stems from `ffmpeg` number frames from 1 - I think all would be good if they started from 0. Check this out and if so update the `count=1` bit of scripting up above. **Note:** at the moment, my last frame is a render with no background, i.e. I'm rendering one more frame than I have underlying video frames.

**Important:** Blender hung when I tried working with it while the render was happening. So in _Output_ properties under _Frame Range_, set _Frame Start_ to where you want to restart from and then press `ctrl-F12` again (it will correctly name the frames, i.e. it won't give the first rendered frame the number 1 but instead use it's actual frame number). **Remember** to reset _Frame Start_ afterward or things get very confusing.

* Switch to the _Video Editing_ workspace, hit the left _Jump to Endpoint_ button to reset the playhead to 1.
* Go to _Add / Image Sequence_ and select all the rendered images.
* In _Output_ properties, select _FFmpeg Video_, expand _Encoding_ and select _High Quality_. Or use _Perceptually Lossless_ and _Slowest_ - this doubles the file size but isn't dramatically slower for such a small number of frames. Press `ctrl-F12` and you'll get a file called something like "0001-0141.mkv" in the same directory as the rendered frames. **Note:** I had to retick _Sequencer_ (see note below), if I'd unticked it, otherwise it would start with a fresh render rather than just combining the images just added to the _Video Sequencer_ editor.

**Note:** I tried rendering with Filmic - it does affect the render result but it also affects the image sequence. **TODO:** work out how to do the render with _Filmic_ and only afterward combine the result such that we get a composited image with the filmic render but the video frames looking as they do when e.g. viewed with `eog`.

**Note:** for whatever reason, once I've rendered a sequence, I always find I have to go to _Output_ properties, the _Post Processing_ section and untick _Sequence_ if I want to rerender. Otherwise, it uses the existing frames (or, if I've restarted Blender, black frames). I suspect it's to do with loading the rendered images back in the _Vide Editing_ workspace.

_Compare Start Frame in the Image node and Start in the camera Object Data_
![img.png](images/frame-mismatch.png)

_Compositing (with Offset set to 1)_  
![img.png](images/compositing.png)

Improving the texture of the canvas
-----------------------------------

The imported image is a painting on canvas. By default, it looks very flat. So I produced normal maps etc. with [AwesomeBump](https://github.com/kmkolasinski/AwesomeBump).

Get the latest release, unzip it and run `RunAwesomeBump.sh` (which just sets up the load-library path to pull in all the Qt libraries etc. that are included).

Click the _Open new image_ icon, select `saint-cropped.png`, click _Enable Preview_ (bottom of the white panel containing all the settings) and assuming you don't want to fine tune the setting, scroll to the bottom of the settings and click _Convert_.

And wait, eventually you'll get a greyscale version of your image (a little confusingly, you see the original AwesomeBump image until the conversion completes).

The tabs along the right side of the settings panel allow you to switch to see the normal, specular, height, occlusion, roughness and metallic images (the tooltips for most of these tabs seem to be broken but you can work out what they are from the corresponding buttons on the right-hand side that share the same images and have working tooltips).

There doesn't seem to be any way to save all the image types in one go, so thru the tabs and press the _Save current image_ tab for each (there's a noticeable pause for the first image - the interface temporarily hangs while the save happens).

I just exported normal and height (for no better reason than that I'd seen in [here](https://www.youtube.com/watch?v=j3lhPKF8qjU&t=3055s) (50m 55s into Gleb Alexandrov's video "Complete Meshroom Tutorial | Photogrammetry Course") that these were the maps you wanted to have for photogrammetry).

Then in Blender, with the "Node Wrangler" add-on enabled, go to the _Shading_ workspace, select the _Principled BSDF_ node of the plane with the image on it (the current image determines the _Base Color_). Now, press `ctrl-shift-T` and select the normal and height images.

These have to be named so Blender can recognise them for what they are, it's a shame AwesomeBump uses slightly different conventions. So to fix things:

```
$ mv saint-cropped_n.png saint-cropped_normal.png
$ mv saint-cropped_h.png saint-cropped_height.png```
```

The result is an impressive set of additional nodes:

![img.png](images/texture-setup.png)

Results
-------

* Original clip: <https://youtu.be/vS037fWgos4>
* With render: <https://youtu.be/gmFCcowbJeM>
* Stabilized: <https://youtu.be/MX-awaTFAFw>

The stabilization was done with and dramatically reduces apparent shake:

```
$ input=result-standard-percep-slow.mkv 
$ ffmpeg -i $input -vf vidstabdetect -f null -
$ ffmpeg -i $input -vf vidstabtransform,unsharp=5:5:0.8:3:3:0.4 -c:v libx264 -preset slow -crf 22 stable_$input
```