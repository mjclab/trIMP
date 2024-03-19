// this code defines a thresholded "cytoplasm" band  around each nuclear seed according to a given image of somatic staining 
// caveat - if there is no cytoplasm signal above threshold the band will not have a dimension and the band ROI will not exist. To avoid errors we remove the corresponding nuclear ROI
// we can count these events based on the trimmed ROI count if needed. But I will keep this behaviour for now

// now seems ready 2024-2-12 MJC

// cleanup
close("*");
print("\\Clear");
if(isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");}
setBatchMode(true);







//parameters
path="L:/Manuscripts_NOS1AP/COSdata/2015-05-19_004/";
well="Well B02/";
Cyto="YFP500 - n000000.tif";
NucRoi="Data_v01i/ROInucB02";//.zip";
nucROIfile=path+NucRoi+".zip";


maximum_distance= 75; //distance from the seeds - same as band_width 
erosion_cycles=2; // erodes the cytoplasmic region in all directions to generate a gap from the nuclear region, but also shrinks from the outside
// define the thresholds here - should be useer input
minimumThreshold = 5; //~15 wo srqt, trying 2 with. Does not work 
maximumThreshold =3550;
outpath_to_nuc="C:/temp/ROInewnuc.zip";
outpath_to_band="C:/temp/ROIbandtosave.zip";
outpath_to_cyto="C:/temp/ROIcytosave.zip";


//generate example data for this macro - open an image and open a nuc ROI file
imagename=demoseg3(path, well, Cyto, NucRoi+".zip");
rename("ThresholdImage"); // this will be just a background-corrected, smoothed image


// preprocess cyto image, here ROUGHLY
	// this bit not working well
	//run("32-bit"); this seems to mess up the algorithm
	//run("Square Root"); does not seem useful in 16 bit mode
run("Subtract Background...", "rolling=50");
run("Median...", "radius=2"); //needed or get a lot of little dots?
run("Enhance Contrast", "saturated=0.35");
// now we have  a background-corrected, smoothed image
imagename="ThresholdImage";

//all-in-one function
GenerateCytoBandsFromNucSeeds(imagename, maximum_distance, erosion_cycles, minimumThreshold, maximumThreshold, nucROIfile, outpath_to_band, outpath_to_cyto, outpath_to_nuc);
	
setBatchMode(false);
print("done");



function demoseg3(L_path, L_well, L_Cyto,L_NucRoi)
	{
	imagename="Untitled";
	//path="L:/Manuscripts_NOS1AP/COSdata/2015-05-19_004/";
	//well="Well B02/";
	//Cyto="YFP500 - n000000.tif";
	////Nuclei="Hoechst - n000000.tif";
	open(L_path+L_well+L_Cyto);//Nuclei);
	rename(imagename);
	//open("L:/Manuscripts_NOS1AP/COSdata/2015-05-19_004/Data_v01i/ROInucB02.zip");
	//NucRoi="Data_v01i/ROInucB02.zip";
	roiManager("Open", L_path+L_NucRoi);
	return imagename;
	}

	
function demoseg()
	{
	imagename="Untitled";
	newImage(imagename, "32-bit black", 200, 240, 1);
	makeRectangle(19, 17, 23, 16);
	roiManager("Add");
	makeRectangle(14, 67, 42, 19);
	roiManager("Add");
	return imagename;
	}


function demoseg2()
	{
	imagename="Untitled";
	run("Blobs (25K)");
	rename(imagename);
	run("Nucleus Counter", "smallest=50 largest=5000 threshold=Current smooth=None subtract watershed add");
	return imagename;
	}
	

	
			
function Bands_without_overlap(template_image, max_distance, erosion_count)
	// this takes a ROImanager list of seeds (nuclei) and expands them all in a non-overlapping way
	//N.B. if initial seeds overlap, there will be trouble! Seems to be OK if they are just touching
	//ROImanager ends up with the band ROIs
	{
	initial_colour = getValue("color.foreground");// temporarily save foreground to ensure fill generates an objective
	setForegroundColor(255, 255, 255);

	//create new image of correct size to work with masks
	 	selectWindow(template_image);
	 	getDimensions(width, height, channels, slices, frames);
	 	newImage("Seeds", "16-bit black", width, height, 1);
	

	//show all ROIs and burn them into the seeds image
		roiManager("Fill");//show all ROIs listed as white
	// code surrounding pixels according to distance from ROIs
		setOption("BlackBackground", true);
		run("Make Binary");
	//run voronoi on a copy	
		run("Select All"); run("Duplicate...", "title=Voronoi");
		run("Voronoi");	run("Invert");
		setThreshold(254, 255, "raw");
		run("Convert to Mask");//thresholded area to white, expanded seeds in black

		setAutoThreshold("Huang dark no-reset");run("Convert to Mask");

	//generate the watershed
		selectWindow("Seeds");
		run("Invert"); //black on white background
		run("Distance Map");//creates gradient of grey levels according to distance
	// expand seeds by setting up threshold on this gradient to define the distance limits
		// this defines how far out the delimiter should go. In attovision it is masked against a second channel - we could consider this
		setAutoThreshold("Default dark");
	//debug max_distance= 30;
		setThreshold(max_distance, 255);  //sets areas further from seeds as thresholded (red)
		run("Convert to Mask");//thresholded area to white, expanded seeds in black
		run("Invert");// now expanded seeds in white
	// draw a line between the expanded seeds
		//run("Watershed"); // this is not useful
	imageCalculator("AND create", "Seeds","Voronoi");
	rename("delimiter_masks");
	
	// This is to draw a line around the image to avoid the edge but it is not needed
	/*getDimensions(width, height, channels, slices, frames);
	print(width, height, channels, slices, frames);
	makeRectangle(0, 0, width-1, 1);run("Cut");	
	makeRectangle(0, 0, 1, height-1);run("Cut");	
	makeRectangle(0, height-1, width, 1);run("Cut");	
	makeRectangle(width-1, 0,1, height);run("Cut");	
	*/
	
	selectWindow("Seeds");close();
	selectWindow("Voronoi");close();
	//loop through nucleus ROIs
	Initial_seed_count=roiManager("count"); //the count will increase ...
	for(ROI=0; ROI<Initial_seed_count; ROI++)
		{
		selectWindow("delimiter_masks");
		roiManager("Select", ROI);
		//roiManager("Select", 1);
//if (ROI>2) stop;
		Roi.getBounds(x, y, width, height);		
//print(x,y,width, height);
		doWand(x+width/2,y+height/2);
		run("Create Mask"); rename("delimiter"); //new image showing max non-overlapping bounds of current ROI
		roiManager("Select", ROI);
	 	run("Make Band...", "band="+max_distance-1);// band_width-1);
		run("Create Mask"); rename("bandmask"); 
		imageCalculator("AND create",  "bandmask","delimiter"); 
		rename("band");

		for(erode=0; erode< erosion_count; erode++) run("Erode"); //erode the shape to separate from the nucleus
		//  note this also erodes from outside so if we really need the max distance, add the erode value to it
		
		run("Create Selection"); // all discontinuous fragments if any are incuded within ROI
		roiManager("Update");//roiManager("Add");
		selectWindow("band"); close();
    	selectWindow("delimiter"); close();
		 selectWindow("bandmask"); close();
		}
	selectWindow("delimiter_masks"); close();
	
	//remove the nulcei now that we have the bands 
	seeds=Array.getSequence(Initial_seed_count);
	print("initial count" + Initial_seed_count);
//Array.print(seeds);
	roiManager("Select", seeds);
//	roiManager("Delete");
	setForegroundColor(initial_colour);
	}



// function to constrain ROIs to areas of intensity matching a threshold			
// assumes ROI list and copy of image for thresholding	(should be bsubbed and smoothed a bit)

// 1. black out area outside ROIs on the image
function blackOutside()
	{
	// function to black out all area
	// join all ROIs together
	roiManager("deselect");	
	roiManager("Combine");
	//roiManager("Add"); not needed
	//select all area outside ROIs
	run("Make Inverse");
	// add this as a new ROI
	roiManager("Add");
	//print(roiManager("count"));
	// black out the image area outside the ROIs
	temp = getValue("rgb.foreground");
	setForegroundColor(0,0,0);
	roiManager("select", roiManager("count")-1);
	roiManager("Fill");//sho
	setForegroundColor(temp);
	// remove this outside-ROI ROI
	roiManager("select", roiManager("count")-1); 
	roiManager("delete");
	}


function ThresholdROIs(minThreshold, maxThreshold)
	{
	//2. Modify each ROI to match the above threshold pixels
	
	// if they don't meet the threshold, make a note to delete the corresponding nuc ROI as well
	ROIcount= roiManager("count");
	nucROIsToRemove=newArray(ROIcount); //array initialises with zeros
	Array.fill(nucROIsToRemove, -1);// use -1 as nothing to remove because 0 points to the first ROI
		
	// select ROI
	for (ROInumber= ROIcount-1; ROInumber>-1; ROInumber--) //start from the end so a deletion does not change the numbering
		{
		//minThreshold = 550;	maxThreshold =3550;	ROInumber=17;
//minThreshold = 50; //nearer 5?
//maxThreshold =3550;
//ROInumber= 4; 
			roiManager("select", ROInumber);
			getSelectionBounds(x, y, w, h);
//print(ROInumber,x,y,w,h);
			run("Duplicate...", "title=temp");
			setThreshold(0, minThreshold); //the range to discard - might be best to use a smoothed image here? consider bckgd
			run("Create Selection");
			if ((selectionType() != -1) && getValue("Mean")!=0) //check it even exists and later again after thresholding      
				{
				run("Set...", "value=0");			
				//run("Restore Selection"); no
				setThreshold(minThreshold+1, maxThreshold); //the
				run("Make Inverse");
				if (selectionType() != -1) 
					{
					getSelectionBounds(x1, y1, w1, h1);
//print(x1,y1,w1,h1);
				setSelectionLocation(x+x1, y+y1); //if selection loses pixels the position will have shifted
				//roiManager("add"); // or it could be update?		
				roiManager("update"); 
				
					}
					else 
					{
					roiManager("delete");
					nucROIsToRemove[ROInumber]=ROInumber;
//print("deleted ROI#"+ROInumber);// this must be saved as an array or the nuc will not have bands
					}
				resetThreshold;	
				//close("temp");
				}
			else  
				{
				roiManager("delete");	
				nucROIsToRemove[ROInumber]=ROInumber;
//print("deleted ROI#"+ROInumber); //  this must be saved as an array or the nuc will not have bands
				}
		close("temp"); // regardless , have to close it
		print("Checked ROI#"+ROInumber+"; "+roiManager("count")+" ROIs remaining");		
		}
	nucROIsToRemove=Array.deleteValue(nucROIsToRemove, -1);	
	return 	nucROIsToRemove;
	}	




function GenerateCytoBandsFromNucSeeds(image_for_cyto_threshold, maximum_distance_from_nuc_edge,  cyto_erosion_cycles, minimumCytoThreshold, maximumCytoThreshold, nucROIpath, ROI_outpath_band,ROI_outpath_cyto, ROI_outpath_nuc)
	{
	// this function generates the initial bands
	Bands_without_overlap(imagename, maximum_distance_from_nuc_edge,  cyto_erosion_cycles);

	// next function shapes ROIs to a given thresholded image - // seems to work 2023-11-07
	selectWindow(image_for_cyto_threshold);
	blackOutside(); // blacks out everything not already in the ROIs from the above band function
	roiManager("Save", ROI_outpath_band);//+"ROIsave1.zip");
	
	// here the cyto-bands are thresholded based on intensities in the image currently selected
	ROIsToDelete=ThresholdROIs(minimumCytoThreshold, maximumCytoThreshold); // this returns an array of which nuc ROIs should be removed for pairing with cyto ROIs
	//save the resulting cyto ROIs; note if any were below threshold they will not exist 
	roiManager("Save", ROI_outpath_cyto);//+"ROIcytosave2.zip");
	roiManager("deselect");roiManager("delete"); // isOpen("ROI Manager") fails here
//print(roiManager("count") + " ROIs remaining"); 
	// get the original nuc ROI file and remove the extras. Make space for it and save the new nucROI file
	roiManager("Open", nucROIfile);
//print(roiManager("count") + " ROIs remaining"); 
	// avoid combining ROI lists
	if (File.exists(ROI_outpath_nuc)) File.delete(ROI_outpath_nuc);//); // avoid combining ROI lists
	if (ROIsToDelete.length >0) //if there is something to delete
		{
//print(roiManager("count"));Array.print(ROIsToDelete);print(ROIsToDelete.length);
		roiManager("select", ROIsToDelete); roiManager("delete");
//print(roiManager("count") + " ROIs remaining"); print("New ROI file at "+ "C:/temp/"+"new.zip");
		roiManager("Save", ROI_outpath_nuc);//"+"newnuc.zip");
		}
	else roiManager("Save", ROI_outpath_nuc);// +"newnuc.zip"); //just copy it here -  in another implementation there is nothing to do in this case
	}

