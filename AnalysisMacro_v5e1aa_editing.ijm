// section 1 merges channels, subtracts backgrounds and aligns images, based on Macro8-BsubByField-AlignFn_withFastCa
// section 2 segments image according to 3rd channel coded in blue, based on LOOP macro 7 ROIexpandandband2 from Merge and Fast Ca
// section 3 collects and saves data from image stacks using the ROIs generated 
   // ***this still lacks settings for NMDA endpoint cellwise difference calculations
// section 4 collates data from the saved well data as a single file for each probe
   // this still lacks settings for NMDA endpoint cellwise difference calculations
//EDIT version - not yet complete - lacking difference calculations

//Note - some run macros have additions within a 50 Ca read event 20 before, 30 after. 
//(Note) There can be xy displacement ~10% of times. Select switch InterburstAlignmentRef to realign to pre or post addition set or "no" to turn off
// Note on use of timewindows. Now we have cell tracking, it becomes important that the timewindowed image series have been aligned to each other to demonstrate tracking on an aligned stack
   // currently, below, preprocess/windowtimecourse disrupts alignment through the stack. 
   // As workaround, I have a separate macro to generate *single* timepoints from an aligned Merge and put them in timewindow directories - replacing preprocess/windowtimecourse below
   // consider in future to generate the aligned merged stack and redistribute to timewindows in stacks as defined by timewindowstep below...
// Citations:
// IJ Schneider, C. A., Rasband, W. S., & Eliceiri, K. W. (2012). NIH Image to ImageJ: 25 years of image analysis. Nature Methods, 9(7), 671–675. doi:10.1038/nmeth.2089
// Fiji Schindelin, J., Arganda-Carreras, I., Frise, E., Kaynig, V., Longair, M., Pietzsch, T., … Cardona, A. (2012). Fiji: an open-source platform for biological-image analysis. Nature Methods, 9(7), 676–682. doi:10.1038/nmeth.2019
// StarDist Schmidt, U., Weigert, M., Broaddus, C., & Myers, G. (2018). Cell Detection with Star-Convex Polygons. In Medical Image Computing and Computer Assisted Intervention – MICCAI 2018 (pp. 265–273). Springer International Publishing. doi:10.1007/978-3-030-00934-2_30
// NanoJ Laine, R. F., Tosheva, K. L., Gustafsson, N., Gray, R. D. M., Almada, P., Albrecht, D., … Henriques, R. (2019). NanoJ: a high-performance open-source super-resolution microscopy toolbox. Journal of Physics D: Applied Physics, 52(16), 163001. doi:10.1088/1361-6463/ab0261
// 
// earlier versions of some of code  previously published in Li LL 2020
// previous? Lindkvist 1995

//Dependencies: 
//Fiji
// - Cookbook, for conventional alignments with MultiStackReg1.45_.jar, TurboReg_StackAlign.jar 
// - Stardist, if this option is selected for segmentation instead of Analyse Particles (as used in Cookbook Nucleus Counter), then maybe does not work in IJ1
// - NanoJ functions DriftEstimation_ and DriftCorrection_ from Laine et al., also in Fast4DReg_-2.0.0-jar-with-dependencies.jar 
// https://github.com/HenriquesLab/NanoJ-Core/tree/master/Core/src/nanoj/core/java/gui
// N.B. this can fails on the fast Ca data. Thresholding procedure has been adapted to cope. Potentially could apply first to condensed ca, and transfer to fast data and reapply? Complicated...


var VersionNumber = "v5e1a_editing";//ready-to-test";
//NOTE - below has optimisations CxN, adjusted values esp ROI and Segmentation Channel
var Verbosity = 1; //0 = off, 1 = minimal, 4 = max	
//some initialisations to avoid errors
RatioPairs=newArray();
//**********ADJUST VALUES HERE //Take care to indicate which of the listed channels is the calcium one with more frames
//**************************************************************************************************
//#@ String (visibility=MESSAGE, value="<html><p>Run analysis based on settings</p></html>") docmsg
#@ String (visibility=MESSAGE, value="<p>Run analysis based on settings<br></p>", persist=true, required= false) docmsg
#@ String (label=" ", choices={"settings at the top of the macro", "in a file to be selected"}, style="radioButtonVertical", persist=true, required=true) SelectedOption


//#@ String(label = "Analysis based on", choices={"Saved File", "Default Values in Macro"}, style="listBox") AnalysisSettingType ;
//#@ File (label="Select saved settings", value = "none", style="extensions:ijm/txt") SettingsFilePath ;

if (SelectedOption=="settings at the top of the macro")  ReadSettingsFromFile= false;	
else {
#@ File (label="Select saved settings", value = "none", style="extensions:ijm/txt", persist= true) SettingsFilePath ; //extensions not settable
ReadSettingsFromFile= true;
SettingsPath=SettingsFilePath; 
SettingsFilename= "";
}

print(SelectedOption, ReadSettingsFromFile, SettingsFilePath);

AnalysisSettingType= "Default Values in Macro";SettingsFilePath= "none";
print(AnalysisSettingType,SettingsFilePath);



	/*
ReadSettingsFromFile= true;//true or false (anothing else but true)
	SettingsPath= "Y:/Data/DataFromBD_A095/"
	SettingsFilename="For_2022-11-11_001.csv";
	*/


//**********ENTER PARAMETERS HERE OR USE THE FILE INPUT ABOVE

function ParametersFromMacro()
		{
		RunListCSV = "2022-11-11_000";// , 2021-06-21_002"; //2019-03\2021-06-21_001\Well D003-04_000, 2019-03-05_001, 2019-03-07_001"; //make sure there is a comma between, if you have more than one experiment queued
		RunList = split(RunListCSV, ","); //no spaces allowed while there are spaces in name!


		DiskWithData = "Y:";
		ExperimentType = "timecourse2ch"; //Choose experiment type //Usage ("opto"|"timecourse"|"endpoint"|"custom"), with typical settings predefined below
		//AUTO! PlateType =96;// 96 or 384, only affects the Well names


		//Choose options to run e.g. if part has already been run 
		DataCopy = false;//false // if true data will be copied from X to Y with DOS command 
		Preprocess = true; // false
			SaveMergedAsAVI = false; //jpeg compressed avi for more convenient viewing
		Segment = true; // false
			UseExistingROIs= false;//false
		CollectData = true; // false
		CollateData = true;  // false // inc 


		ConstrainWells = true; ConstrainedWells= newArray("C", "C", "10", "10"); //first row, last row, first col, last col
			//if you want to constrain wells (>ConstrainWells=true;), change the string array (use upper case characters in quotes for rows  first, and then numbers in quotes e.g.ConstrainedWells= newArray("A", "P", "1", "24");
		ChannelNames_explicit = false; //true|false ::if false, calls a function to find the complete channel names based on the info given e.g. "jR" will find "jRCaMP30ms". WARNING: if jR exists twice in the top folder it will fail!
		//Alignment is defined by Alignerchannel below

		WindowTimecourse = false; //false // true // 
			TimeWindowFirst=1;
			TimeWindowLast=180;
			TimeWindowStep=36; // this will limit baseline reads; make sure it's smaller than last or this will not do what you want!
			// if 1, bugs to fix,...
			MergeWindowFiles = true;// true requires existence of the data files to be collected


		if (ExperimentType=="opto")
		{//settings for opto experiments
		DifferenceCalc = false; //not used 
		GroupCount = 2; // Usage GroupNumber = [1 or 2]  Note that we assume here that B02 is group 1 so A01 would be group2
		GroupType = "Column";//"Column"  //Define how groups are arranged for this dataset - either alternating by Row or Column, or "", anything else is too complicated
		ImageKernels = newArray("YFP", "YFP", "jRCaMP100ms", "CFP_1s", "YFP01", "jRCaMP100ms");
		GeometricCorrection = newArray(0,0,1,0,0,1);
		SignalNamesRGBgroups =newArray("copy", "ERK", "Ca", "opto", "ERK", "Ca");
		CalciumChannel= 3; //used in several places
		CondenseFactor = 20;//Number of calcium images per kinase image **********ADJUST VALUE HERE //default = 20 Ca images per kinase image  for opto-experiments
		InterburstAlignmentRef = "no";
		BaselineReads = 8;//Analysis setting
		experiment_ID = "CxN Tq-optoByRow Y-Erk jRnuc PIC";//"CxN Tq-optoByCol Y-Erk jRnuc PIC";
		}


		else if (ExperimentType=="timecourse1ch")
		{//settings for usual PIC stimulation experiments
		DifferenceCalc = false; //not used 
		GroupCount =1; //1  // Usage GroupNumber = [1 or 2]  Note that we assume here that B02 is group 1 so A01 would be group2
		GroupType = "none";//"none", Row";//"Column"  not empty!!!//Define how groups are arranged for this dataset - either alternating by Row or Column, or "", anything else is too complicated
		ImageKernels = newArray("iR");//, "CFP_1s", "YFP01", "jRCaMP100ms");
		GeometricCorrection = newArray("0"); // for single numeric array, put number in quotes or it is taken as vector length
		SignalNamesRGBgroups =newArray("Ca");//, "opto", "ERK", "Ca");
		CalciumChannel= -1; //used in several places
		CondenseFactor = 1;//Number of calcium images per kinase image **********ADJUST VALUE HERE //default = 20 Ca images per kinase image  for opto-experiments
		InterburstAlignmentRef = "no";// USAGE "pre" "post" "no" for xydrift corrections during pipetting
		CaFramespreAdd =20; CaFramespostAdd =30;
		BaselineReads = 1;//Analysis setting
		experiment_ID = "FPs";//"Synaptoneurosome staining";//"CxN 384pip ERKktr jR OptoSlims";//CxN 384pip ERKktr jR OptoSlims";//"CxN 384pip Tq-JNK Y-ERK iR-p38 jRnuc";// "CxN 384 Tq-JNK Y-ERK jRnuc Inhs";//CxN 384pip Tq-JNK Y-ERK jRnuc Inhs"; //  CxN Tq-JNK Y-ERK jRnuc Inhs";//CxN Tq-JNK Y-ERK jRnuc PICdev";//CxN Tq-JNK Y-ERK jRnuc Inhs";//
		}


		else if (ExperimentType=="timecourse2ch")
		{//settings for usual PIC stimulation experiments
		DifferenceCalc = false; //not used 
		GroupCount =1; //1  // Usage GroupNumber = [1 or 2]  Note that we assume here that B02 is group 1 so A01 would be group2
		GroupType = "none";//"none", Row";//"Column"  not empty!!!//Define how groups are arranged for this dataset - either alternating by Row or Column, or "", anything else is too complicated
		ImageKernels = newArray("CFP", "RR");//, "CFP_1s", "YFP01", "jRCaMP100ms");
		GeometricCorrection = newArray(0,1);
		SignalNamesRGBgroups =newArray("ERK","Ca");//, "opto", "ERK", "Ca");
		RatioPairs=newArray("2v1"); //Just set it to newArray() if you don't want to calculate ratios, other wise it is "1v2" for 1/2  ; have to use v no space (excel kills / and :) 
		CalciumChannel= 2; //used in several places
		CondenseFactor = 50;//Number of calcium images per kinase image **********ADJUST VALUE HERE //default = 20 Ca images per kinase image  for opto-experiments
		InterburstAlignmentRef = "pre";// USAGE "pre" "post" "no" for xydrift corrections during pipetting
		CaFramespreAdd =20; CaFramespostAdd =30;
		BaselineReads = 4;//Analysis setting
		experiment_ID =  "human neuron";//"CxN 384pip ERKktr jR OptoSlims";//CxN 384pip ERKktr jR OptoSlims";//"CxN 384pip Tq-JNK Y-ERK iR-p38 jRnuc";// "CxN 384 Tq-JNK Y-ERK jRnuc Inhs";//CxN 384pip Tq-JNK Y-ERK jRnuc Inhs"; //  CxN Tq-JNK Y-ERK jRnuc Inhs";//CxN Tq-JNK Y-ERK jRnuc PICdev";//CxN Tq-JNK Y-ERK jRnuc Inhs";//
		}



		else if (ExperimentType=="timecourse3ch")
		{//settings for usual PIC stimulation experiments
		DifferenceCalc = false; //not used 
		GroupCount =1; //1  // Usage GroupNumber = [1 or 2]  Note that we assume here that B02 is group 1 so A01 would be group2
		GroupType = "none";//"none", Row";//"Column"  not empty!!!//Define how groups are arranged for this dataset - either alternating by Row or Column, or "", anything else is too complicated
		ImageKernels = newArray("CFP", "YFP", "RR");//, "CFP_1s", "YFP01", "jRCaMP100ms");
		GeometricCorrection = newArray(0,0,1); //will apply geometric correction if 1, not if 0
		//needed where em filter is 700/75 or ET600/60 but not for 645/75
		SignalNamesRGBgroups =newArray("JNK", "ERK", "Ca");//, "opto", "ERK", "Ca")
		RatioPairs=newArray(); // Just set it to newArray() if you don't want to calculate ratios, other wise it is "1:2" for 1/2
		CalciumChannel= 3; //used in several places
		CondenseFactor = 10;//Number of calcium images per kinase image **********ADJUST VALUE HERE //default = 20 Ca images per kinase image  for opto-experiments
		InterburstAlignmentRef = "no";//"pre";// USAGE "pre" "post" "no"
		CaFramespreAdd =20; CaFramespostAdd =30;
		BaselineReads = 4;//Analysis setting
		experiment_ID = "CxN 384pip ERKktr jR NMDA MK";//	experiment_ID = "CxN Tq-MK2orJNK Y-ERK jRnuc Inhs";//
		//experiment_ID = "CxN 384pip Tq-JNK Y-ERK jRnuc Inhs";//"CxN 384pip Tq-JNK Y-ERK iR-p38 jRnuc";// "CxN 384 Tq-JNK Y-ERK jRnuc Inhs";//CxN 384pip Tq-JNK Y-ERK jRnuc Inhs"; //  CxN Tq-JNK Y-ERK jRnuc Inhs";//CxN Tq-JNK Y-ERK jRnuc PICdev";//CxN Tq-JNK Y-ERK jRnuc Inhs";//
		}
		else if (ExperimentType=="timecourse4ch")
		{//settings for usual PIC stimulation experiments
		DifferenceCalc = false; //not used 
		GroupCount =1; //1  // Usage GroupNumber = [1 or 2]  Note that we assume here that B02 is group 1 so A01 would be group2
		GroupType = "none";//"none", Row";//"Column"  not empty!!!//Define how groups are arranged for this dataset - either alternating by Row or Column, or "", anything else is too complicated
		ImageKernels = newArray("CFP", "YFP", "RR", "iR");//, "CFP_1s", "YFP01", "jRCaMP100ms");
		GeometricCorrection = newArray(0,0,1,1); //will apply geometric correction if 1, not if 0
		//needed where em filter is 700/75 or ET600/60 but not for 645/75
		SignalNamesRGBgroups =newArray("SpyCatcher", "mNG", "Spytag", "NLS");//, "opto", "ERK", "Ca");
		CalciumChannel= 4; //used in several places
		CondenseFactor = 10;//Number of calcium images per kinase image **********ADJUST VALUE HERE //default = 20 Ca images per kinase image  for opto-experiments
		InterburstAlignmentRef = "pre";// "pre";// USAGE "pre" "post" "no"
		CaFramespreAdd =20; CaFramespostAdd =30;
		BaselineReads = 5;//Analysis setting
		experiment_ID = "SplitComplementation";//"CxN 384pip Tq-JNK Y-ERK iR-p38 jRnuc";// "CxN 384 Tq-JNK Y-ERK jRnuc Inhs";//CxN 384pip Tq-JNK Y-ERK jRnuc Inhs"; //  CxN Tq-JNK Y-ERK jRnuc Inhs";//CxN Tq-JNK Y-ERK jRnuc PICdev";//CxN Tq-JNK Y-ERK jRnuc Inhs";//
		}



		else if (ExperimentType=="multichannel")
		{//settings for usual PIC stimulation experiments
		DifferenceCalc = false; //not used 
		GroupCount =1; //1  // Usage GroupNumber = [1 or 2]  Note that we assume here that B02 is group 1 so A01 would be group2
		GroupType = "none";//"none", Row";//"Column"  not empty!!!//Define how groups are arranged for this dataset - either alternating by Row or Column, or "", anything else is too complicated
		ImageKernels = newArray("CC", "YY", "RR", "iR");//"BB01",  "CC01", "CR01", "YY01", "RR01", "II", "BC01", "CR''01","RR''01", "YgGlp01");//, "CFP_1s", "YFP01", "jRCaMP100ms");
		GeometricCorrection = newArray(0,0,1,1);//,0,0,0,0,0,0);
		SignalNamesRGBgroups =newArray("SpyCatcher", "mNG", "Spytag", "NLS");//BB01",  "CC01", "CR01", "YY01", "RR01", "II01", "BC01", "CR''01","RR''01", "YgGlp01");//, "opto", "ERK", "Ca");
		CalciumChannel= -1; //used in several places
		CondenseFactor = 50;//Number of calcium images per kinase image **********ADJUST VALUE HERE //default = 20 Ca images per kinase image  for opto-experiments
		InterburstAlignmentRef = "no";// USAGE "pre" "post" "no" for xydrift corrections during pipetting
		CaFramespreAdd =20; CaFramespostAdd =30;
		BaselineReads = 1;//Analysis setting
		experiment_ID =  "Barbara";//"test-channels";//"CxN 384pip ERKktr jR OptoSlims";//CxN 384pip ERKktr jR OptoSlims";//"CxN 384pip Tq-JNK Y-ERK iR-p38 jRnuc";// "CxN 384 Tq-JNK Y-ERK jRnuc Inhs";//CxN 384pip Tq-JNK Y-ERK jRnuc Inhs"; //  CxN Tq-JNK Y-ERK jRnuc Inhs";//CxN Tq-JNK Y-ERK jRnuc PICdev";//CxN Tq-JNK Y-ERK jRnuc Inhs";//
		}



		else if (ExperimentType=="endpoint")
		{//settings for usual NMDA endpoint experiments
		DifferenceCalc = true; //not yet implemented
		GroupCount = 1; //1  // Usage GroupNumber = [1 or 2]  Note that we assume here that B02 is group 1 so A01 would be group2
		GroupType = "none";//"none", Row";//"Column"  not empty!!!//Define how groups are arranged for this dataset - either alternating by Row or Column, or "", anything else is too complicated
		ImageKernels = newArray("CFP01", "YFP_1s", "miRFP670", "jRCaMP400ms");//, "CFP_1s", "YFP01", "jRCaMP100ms");
		GeometricCorrection = newArray(0,0,1,0); //will apply geometric correction if 1, not if 0
		//needed where em filter is 700/75 or ET600/60 but not for 645/75
		SignalNamesRGBgroups =newArray("ERK", "NLS", "JNK", "Ca");//("MK2", "ERK", "Ca");//, "opto", "ERK", "Ca");
		CalciumChannel= 4; //used in several places
		CondenseFactor = 5;//Number of calcium images per kinase image **********ADJUST VALUE HERE //default = 20 Ca images per kinase image  for opto-experiments
		InterburstAlignmentRef = "no";
		CaFramespreAdd =20; CaFramespostAdd =30;
		BaselineReads = 1;//Analysis setting
		experiment_ID = "CxN 384pip ERKktr jR NOS1AP";// CxN 384pip Tq-JNK Y-ERK jRnuc Inhs";
		// ***************note difference calculations missing here, still need to add them
		}

		else if (ExperimentType=="custom")
		{//settings for usual PIC stimulation experiments, adjust as needed
		DifferenceCalc = false; //not used 
		GroupCount =1; //1  //Define number of groups //Usage GroupNumber = [1 or 2]  Note that we assume here that B02 is group 1 so A01 would be group2
		GroupType = "none";//"none", Row";//"Column"  not empty!!!//Define how groups are arranged for this dataset - either alternating by Row or Column, or "", anything else is too complicated
		ImageKernels = newArray("CFP01", "YFP01", "Cherry");//, "CFP_1s", "YFP01", "jRCaMP100ms"); "None"
		GeometricCorrection = newArray(0,0,1); //will apply geometric correction if 1, not if 0
		//needed where em filter is 700/75 or ET600/60 but not for 645/75

		SignalNamesRGBgroups =newArray("ERK", "NLS", "NOS1AP");//, "opto", "ERK", "Ca");
		CalciumChannel = -1;//3; //used in several places. Set to -1 means that there is no calcium channel
		CondenseFactor = 1;//Number of calcium images per kinase image **********ADJUST VALUE HERE //default = 20 Ca images per kinase image  for opto-experiments
		InterburstAlignmentRef = "no";// USAGE "pre" "post" "no"
		CaFramespreAdd =20; CaFramespostAdd =30;
		BaselineReads = 5;//Analysis setting
		experiment_ID = "CxN 384pip ERKktr jR NOS1AP";//CxN 384 LifeactTq Y-ERK jRnuc Inhs";
		}

		else FatalError("Experiment Type to analyse is not defined. Please check the parameters entered");





		//Preprocessing parameters - Alignment
		RB =200; //rolling ball for background subtraction
		AlignWithNanoJ = true; // true or false - experimental 202121026 - seems to work for multicell images, but with single cell 40x it introduced jitter. How to add QC? Is there a pattern in the drift output indicating a problem?
		AlignerChannelNumber =2; //Usage -1,0,1,2,3,[anything else] means the channel that gets coded as 1 red, 2 green, 3 blue is used for alignment of the three channels and then everything else is adjusted similarly, 
		//0 means each channel separately aligned, -1 or anything else means there is no alignment
		//for typical neuron tc with nuc Ca indicator, 3 was used. But 1 seems to work OK, and seems much better for quantitative analysis of JNK - small changes need accurate alginment .                 Note that FastCa stack is aligned to Ca from Merged stack whatever value is specified here. That is to avoid failures resulting here from aligning cyto to nuc
		//ALIGNERCHANNEL number  WILL MOVE TO THE CHANNEL TYPE DEFINITIONS


		// File location paramers. Not  changing frequently
		datapath="Data\\DataFromBD_A095\\";
		user_ID = "MJC2022";



		//for Analysis||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

		//Segmentation settings||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
		// Either conventional "analyse particles" like nucleus counter or stardist
		// SegmentationSetting parameters are 
		// rollingball value after SQRT (-1 means dont use), minsize, maxsize, smooth ("median_radius"+3|5) or "none" etc , do not use ""!!), watershed_true-false, Squareroot 1 yes, -1 no, 0 default (=  not if only if 1 frame after compression, or using stardist)
		// size in calibrated pixel sizes as defined in image metadata
		// if use stardist, results are filtered by size constriants and borders are avoided based on max size, and square root is used if 1; rest are not used
		SegmentationSettings = newArray(50, 50, 500, "no smoothing", true, 0);//  for cortical neurons
		// newArray(50, 20, 500, "median_radius"+3, true, false);//  for human neurons  10xNA0.4 segmenting on jRCaMP1b
		// newArray(100, 50, 1000, "median_radius"+3, true, false) works well for hippocampal neurons 10xNA0.4 segmenting on mTq2-Spycatcher

		// HINT if too many objects are being picked up, consider to set RB -1, smooth 1 (means median 3x3) and increase min size. This can help avoid picking up noise better than filters in some cases
		UseStarDist = true; // 
				




		ErodeCycles = 2;  //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! default = 2 for cells segmen5ed by nuclear marker, but 0 for synaptoneurosomes //Segmentation parameters - to separate nuclear and cytoplasmic zones
		ModifyWidthOfBand=false ; //default
		BandWidth=1; //this is default
		NoOverlapBandAlgorithm=false ;
		
		
		SegmentationChannel =2;//CalciumChannel;//3;//4; // use 4, that's the nuclear calcium channel at the moment
		//SEGMENTATION CHANNEL WILL MOVE TO THE CHANNEL TYPE DEFINITIONS
		MaxROIsPerField = 1000; //if more than this number is generated, assume something is wrong and set to zero, which skips to next well (otherwise system can hang)
		//*************************increase this for multiple fields!! and report failures too!********************

		//Thresholding and data collection options. These values seem to work. If changed, the change will be recorded in the directory name 
		//You should  expand the Threshold arrays to match the number of channels. Extra entries don't harm but will generate a warning as they are not used
		Threshold_AbsoluteMin =newArray(5,5,5,5); //can specifically lower threshold in one channel if label is not in all samples
		Threshold_AbsoluteMax =newArray(3000,3000,3000,3000);
		Threshold_AverageMin =newArray(0,0,0,0);
		Threshold_AverageMax =newArray(4095,4095,4095,4095);
		//these are passed to the thresholding function
		//note more thresholds than channels tolerated, but fewer will terminate macro
		//note average gates can be done later from cell-wise averages




		//colour channel arranger in case you want to change it. Only 7 merge channels allowed because 
		//colours are in order 1 red, 2 green, 3 blue, 4 gray, 5 cyan, 6 magenta, 7 yellow. starting at 1 not 0, so just add the zero
		//colour= newArray(8);//does it work >7?
		colour = newArray(0, 1, 2, 3, 4, 5, 6, 7);


		ImageTimeInterval = "1 min";
		GeometricDistortionCorrectionFactor=1.005;// 1.007;//1.015; 
		//1.015 used for Olympus 10x04 PE cell carrier plate -> now 1.007
		// 1.012 was used for Olympus 10x04 Greiner 96w µclear
		//used for miRFP670 images through 700/75 filter so they align with CFP-YFP-Red ones
		//used for red images through 620/60 filter so they align with CFP-YFP ones

		//*************************************************************************************************************************************
		//**END OF USER-MODIFIABLE PARAMETERS

		//*************************************************************************************************************************************


		OutputFolderKernel = "CollatedData_A" + AlignerChannelNumber+ "S" + SegmentationChannel+"_";

		Channels = ImageKernels.length;
		if ((Threshold_AbsoluteMin.length!=Channels)||(Threshold_AbsoluteMax.length!=Channels)||(Threshold_AverageMin.length!=Channels)||(Threshold_AverageMax.length!=Channels)) print("WARNING - Thresholds and Channel count do not match");
		if ((Threshold_AbsoluteMin.length<Channels)||(Threshold_AbsoluteMax.length<Channels)||(Threshold_AverageMin.length<Channels)||(Threshold_AverageMax.length<Channels)) {print("Fatal error - insufficient thresholds defined for channels used - aborting"); stop;}
		Threshold_AbsoluteMin= Array.trim(Threshold_AbsoluteMin, Channels);
		Threshold_AbsoluteMax= Array.trim(Threshold_AbsoluteMax, Channels);
		Threshold_AverageMin= Array.trim(Threshold_AverageMin, Channels);
		Threshold_AverageMax= Array.trim(Threshold_AverageMax, Channels);
		//ThresholdCode="Threshold"+replace(array2str(Array.concat(Threshold_AbsoluteMin, Threshold_AbsoluteMax, Threshold_AverageMin, Threshold_AverageMax)), ",", "");
		ThresholdArray = Array.concat(Threshold_AbsoluteMin, Threshold_AbsoluteMax, Threshold_AverageMin, Threshold_AverageMax);//and length 4* Channels
		ThresholdCode = "Threshold"; for(i=0;i<ThresholdArray.length; i++) {ThresholdCode+=toString(parseInt(ThresholdArray[i]));} //"Min"+MinThreshold+"Max"+MaxThreshold+"Avg"+"_"+NonSegmentationImages[0]+AvgThresholdMinChannel0+"-"+AvgThresholdMaxChannel0+"_"+NonSegmentationImages[1]+AvgThresholdMinChannel1+"-"+AvgThresholdMaxChannel1;
		AlignmentFolder="ImagesAlignedtoCh"+AlignerChannelNumber;
		SegmentationFolder = "SegmentationData_A" + AlignerChannelNumber+ "S" + SegmentationChannel; //options "" or some name (use the same all the time)

		// put all parameters to string array

		settinglines= newArray(101); //currently 68 lines and one more for passing info, here we fill them from data put in the macro
		settinglines[0]= ",Parameter, Value [any value for a parameter name in square brackets cannot be read in]";
		settinglines[1]="1,[Generated by Macro Version:],"+VersionNumber;
		settinglines[2]="2,RunList,"+array2str(RunList);	
		settinglines[3]="3,Disk,"+DiskWithData;	
		settinglines[4]="4,datapath,"+datapath;	
		settinglines[5]="5,user_ID,"+user_ID;	
		settinglines[6]="6,experiment_ID,"+experiment_ID;	
		settinglines[7]="7,[Datestamp],"+"placeholder";	
		settinglines[8]="8,[CurrentRun],"+RunList[0];	
		settinglines[9]="9,Constrain Wells,"+bool2str(ConstrainWells);	
		settinglines[10]="10,Well range if constrained,"+array2str(ConstrainedWells);	
		settinglines[11]="11,Analyse the data as consecutive time windows,"+bool2str(WindowTimecourse);	
		settinglines[12]="12,First timepoint to analyse if windowed,"+TimeWindowFirst;	
		settinglines[13]="13,Last timepoint to analyse if windowed,"+TimeWindowLast;	
		settinglines[14]="14,Window width analysed in windows,"+TimeWindowStep;	
		settinglines[15]="15,Collate Merged Window Data,"+bool2str(MergeWindowFiles);	
		settinglines[16]="16,[Activities selected],"+"see below";	
		settinglines[17]="17,DataCopy,"+bool2str(DataCopy);	
		settinglines[18]="18,Preprocess,"+bool2str(Preprocess);	
		settinglines[19]="19,option SaveMergedAsAVI,"+bool2str(SaveMergedAsAVI);	
		settinglines[20]="20,Segment,"+bool2str(Segment);	
		settinglines[21]="21,option UseExistingROIs,"+bool2str(UseExistingROIs);	
		settinglines[22]="22,CollectData,"+bool2str(CollectData);	
		settinglines[23]="23,CollateData,"+bool2str(CollateData);	
		settinglines[24]="24,[Channels],"+"see below";	
		settinglines[25]="25,Number of Channel Groups,"+GroupCount;	
		settinglines[26]="26,Group Type (if >1 group),"+GroupType;	
		settinglines[27]="27,ImageKernels,"+array2str(ImageKernels);	
		settinglines[28]="28,Image filenames are explicity defined,"+bool2str(ChannelNames_explicit);	
		settinglines[29]="29,SignalNamesRGBgroups,"+array2str(SignalNamesRGBgroups);	
		settinglines[30]="30,Geometric Correction of channels,"+array2str(GeometricCorrection);	
		settinglines[31]="31,Geometric Distortion Correction Factor,"+GeometricDistortionCorrectionFactor;	
		settinglines[32]="32,CalciumChannel,"+CalciumChannel;	
		settinglines[33]="33,Align images either side of an addition point,"+InterburstAlignmentRef;	
		settinglines[34]="34,Ca Frames before the addition,"+CaFramespreAdd;	
		settinglines[35]="35,Ca Frames after (must add up to value below),"+CaFramespostAdd;	
		settinglines[36]="36,Ca images per pathway image,"+CondenseFactor;	
		settinglines[37]="37,Number of Time intervals as Baseline,"+BaselineReads;	
		settinglines[38]="38,Time inverval between pathway images,"+ImageTimeInterval;	
		settinglines[39]="39,[Time inverval between calcium images],"+(parseInt(ImageTimeInterval)/CondenseFactor);	
		settinglines[40]="40,Calculate ratios of the following pairs,"+array2str(RatioPairs);	
		settinglines[41]="41,Preprocess RB,"+RB;	
		settinglines[42]="42,[AlignmentSettings],"+"see below";	
			entry=(AlignerChannelNumber!=-1);
		settinglines[43]="43,Channels and timepoints will be aligned,"+bool2str(entry);	
		settinglines[44]="44,Align to channel,"+AlignerChannelNumber;	
			if (AlignerChannelNumber>0) entry ="prefix="+ImageKernels[AlignerChannelNumber-1] +" for "+SignalNamesRGBgroups[AlignerChannelNumber-1]; 
			else if (AlignerChannelNumber==0) entry= "independent alignment"; 
		settinglines[45]="45,[this is],"+entry;	
		settinglines[46]="46,AlignWithNanoJ,"+bool2str(AlignWithNanoJ);	
		settinglines[47]="47,[Folder with Aligned Merged data],"+AlignmentFolder;	
		settinglines[48]="48,[SegmentationSettings],"+"see below";	
		settinglines[49]="49,RB before sqrt if any,"+SegmentationSettings[0];	
		settinglines[50]="50,Min size,"+SegmentationSettings[1];	
		settinglines[51]="51,Max size,"+SegmentationSettings[2];	
		settinglines[52]="52,AnalyseParticles option smoothing,"+SegmentationSettings[3];	
		settinglines[53]="53,AnalyseParticles option watershed,"+bool2str(SegmentationSettings[4]);	
		settinglines[54]="54,Square root (1 yes; -1 no; 0 default),"+SegmentationSettings[5];	
			if (UseStarDist) entry="StarDist"; else entry = "";
		settinglines[55]="55,Segmentation Method (StarDist or AnalyseParticles),"+entry;	
		settinglines[56]="56,Segment on channel,"+SegmentationChannel;	
		settinglines[57]="57,[this is],"+"prefix="+ImageKernels[SegmentationChannel-1] +" for "+SignalNamesRGBgroups[SegmentationChannel-1];	
		settinglines[58]="58,[SegmentationFolder],"+SegmentationFolder;
		settinglines[59]="59,ErodeCycles,"+ErodeCycles;	
		settinglines[60]="60,MaxROIsPerField,"+MaxROIsPerField;	
		settinglines[61]="61,Threshold_AbsoluteMin by channel,"+array2str(Threshold_AbsoluteMin);	
		settinglines[62]="62,Threshold_AbsoluteMax by channel,"+array2str(Threshold_AbsoluteMax);	
		settinglines[63]="63,Threshold_AverageMin by channel,"+array2str(Threshold_AverageMin);	
		settinglines[64]="64,Threshold_AverageMax by channel,"+array2str(Threshold_AverageMax);	
		settinglines[65]="65,[Output folder kernel],"+OutputFolderKernel;	
		settinglines[66]="66,[Data output folder],"+OutputFolderKernel+ThresholdCode;	
		settinglines[67]="67,colour mapping to first 8 channels,"+array2str(colour);	
		//new settings added 
		settinglines[68]= "68,Width of Band," +BandWidth;  
		settinglines[69]= "69,Modify band compartment width from default," + bool2str(ModifyWidthOfBand);
		settinglines[70]= "70,Use algorithm to prevent overlap between bands (experimental)," + NoOverlapBandAlgorithm; 
		


		return settinglines;
		}

function checkBandWidth(ParameterValues, type)
	{
	BandWidthFault = (returnsetting(ParameterValues, "Modify band compartment width from default", "boolAsInt")  & isNaN(returnsetting(ParameterValues, "Width of Band", "int")));
	if (BandWidthFault & (type!="silent"))
			showMessage("Either deselect the 'Modify BandWidth Compartment' checkbox or enter a number for the band width");
	return !BandWidthFault;
	}
	

function checkChannelNumbers(ParameterValues, type, NumChannels)
	{
	TestArray= newArray("CalciumChannel", "Segment on channel", "Align to channel");
	
	ChannelSelectionFault = false; //default
	for (test = 0; test < TestArray.length; test++)
		{
		testOutcome = (returnsetting(ParameterValues, TestArray[test], "int")> NumChannels);
		if (testOutcome & (type!="silent"))
			showMessage(TestArray[test]+" # is more than total number of channels, please correct");
		if (!ChannelSelectionFault	& testOutcome) ChannelSelectionFault= true;
		}
	return !ChannelSelectionFault;
	}
	
	
		
function checkChannelParameterCount(ParameterValues, type,NumChannels)
	{			 
		// First check that channel arrays are equal and generate a warning message if not
		// read number of channels based on input kernels 
		// check the following
		ChannelMismatchFlag = newArray(6); for (i=0;i<ChannelMismatchFlag.length; i++) ChannelMismatchFlag[i]=0;
		ChannelMismatchType= newArray(6); 
			ChannelMismatchType[0]="SignalNamesRGBgroups/Number of Groups";
			ChannelMismatchType[1]="GeometricCorrection (0 means no, and 1 means yes)";
			ChannelMismatchType[2]="Threshold_AbsoluteMin";
			ChannelMismatchType[3]="Threshold_AbsoluteMax";
			ChannelMismatchType[4]="Threshold_AverageMin";
			ChannelMismatchType[5]="Threshold_AverageMax";
		ChannelParameterLength = newArray(6);
			SignalNamesRGBgroups=returnsetting(ParameterValues, "SignalNamesRGBgroups", "stringarray"); 
				ChannelParameterLength[0] = SignalNamesRGBgroups.length;
			GeometricCorrection=returnsetting(ParameterValues, "Geometric Correction of channels", "values"); //int array
				ChannelParameterLength[1] =  GeometricCorrection.length;
			Threshold_AbsoluteMin=returnsetting(ParameterValues, "Threshold_AbsoluteMin by channel", "value(s)"); //array
				ChannelParameterLength[2] =  Threshold_AbsoluteMin.length;
			Threshold_AbsoluteMax=returnsetting(ParameterValues, "Threshold_AbsoluteMax by channel", "value(s)"); //array
				ChannelParameterLength[3] =  Threshold_AbsoluteMax.length;
			Threshold_AverageMin=returnsetting(ParameterValues, "Threshold_AverageMin by channel", "value(s)"); //array
				ChannelParameterLength[4] =  Threshold_AverageMin.length;
			Threshold_AverageMax=returnsetting(ParameterValues, "Threshold_AverageMax by channel", "value(s)"); //array
				ChannelParameterLength[5] =  Threshold_AverageMax.length;
		
		// special case for ChannelParameter[0]
		Ngroups=returnsetting(ParameterValues, "Number of Channel Groups", "int");
		if( ChannelParameterLength[0]!=NumChannels*Ngroups) ChannelMismatchFlag[0]=1;
		 for (i=1;i<ChannelMismatchFlag.length; i++) if( ChannelParameterLength[i]!=NumChannels) ChannelMismatchFlag[i]=1;
			  
			
		Flagged= Array.sort(ChannelMismatchFlag);
		if (Flagged[Flagged.length-1]>0) 
			{//debug - was probably a typo - remove trailing commas then?
			/*Msg= "Flaggedlength = "+Flagged.length + "\n";
			Msg= Msg+"Flagged  = "+ array2str(Flagged) + "\n";
			Msg= Msg+"ChannelParameterLength  = " +array2str(ChannelParameterLength) + "\n";
			Msg= Msg+"Threshold_AverageMax  = "+ array2str(Flagged) + "\n";
			Msg= Msg+"Threshold_AverageMin  = " +array2str(Threshold_AverageMin) + "\n";
			Msg= Msg+"Threshold_AverageMin.length = "´+Threshold_AverageMin.length + "\n";
			Msg= Msg+"Threshold_AverageMax  = " +array2str(Threshold_AverageMax) + "\n";
			Msg= Msg+"Threshold_AverageMax.length = "+Threshold_AverageMax.length + "\n";
			showMessage(Msg);
			*/
			if (type!="silent") //pre-check informs user, post-check is to flag requirement to ask again
				{
				Msg= "The following settings must have the same number of values as the Image kernels entry (="+NumChannels + "). Please fix this or the script cannot run.\n\n";
				for (i=0;i<ChannelMismatchFlag.length; i++) if (ChannelMismatchFlag[i]==1) Msg= Msg+"      >" + ChannelMismatchType[i]+", which currently has "+ChannelParameterLength[i]+" values;\n\n";
				showMessage(Msg);
				}
			return false ;
			}
		else return true ;	
	}




function parameterDisplay(InitialParameters) // note the old dialog requires the dialog writing and reading to be carefully matched - don't separate them
		{
		
		// Show all parameters so they can be edited at this point
		// using index 100 for status of parameters, should have used index 0..
		//print(InitialParameters[100]);
		if (InitialParameters[100]==-1) title = "Parameters Loaded - make any changes that might be needed";
		else title = "Confirm the "+ InitialParameters[100]+ " changes made or make more changes";
		
		
		// issue guidance if channel parameters do not match the number of channels - pack this in a separate function
		ImageKernels=returnsetting(InitialParameters, "ImageKernels", "stringarray"); 
		
		validChannelParameterCount=checkChannelParameterCount(InitialParameters, "message",ImageKernels.length); 
			if (!validChannelParameterCount) title ="Ensure each channel has the required parameters. "+ title;
		validChannelCount=checkChannelNumbers(InitialParameters, "message",ImageKernels.length);
			if (!validChannelCount) title ="Ensure you have not specified channel #s > # Image Kernels="+ImageKernels.length+". "+ title;
		validBandWidthsettings=  checkBandWidth(InitialParameters, "message");
			if (!validChannelParameterCount) title =  "Check BandWidth is valid. "+ title;
		
		
		  FontSize= 12;
		  Dialog.create(title);
		  color0="000000";
		  color1="ff0000";
		
		
		
		Dialog.setLocation(0,0)
		
		//Dialog.addMessage("Path settings",  FontSize, color1);
			RunList= returnsetting(InitialParameters, "RunList", "stringarray");
			Dialog.addString("Experiments " ,String.join(RunList, ","), 80);
		  
			Dialog.addString("Disk" ,returnsetting(InitialParameters, "Disk",  "string"), 2);
			Dialog.addToSameRow(); Dialog.addString("Data Path" ,returnsetting(InitialParameters, "datapath",  "string"),20);
			Dialog.addString("user_ID" ,returnsetting(InitialParameters, "user_ID",  "string"));
			Dialog.addToSameRow(); Dialog.addString("experiment_ID" ,returnsetting(InitialParameters, "experiment_ID",  "string"), 15);
		//Dialog.setInsets(0,180,0); 
		//Dialog.addMessage("Well settings",  FontSize, color1);      
			WellRowOptions= newArray("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P");
			WellColOptions= newArray("1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","23","24");
			Dialog.addCheckbox("Constrain Wells Analysed", returnsetting(InitialParameters, "Constrain Wells", "boolAsInt"));
				ConstrainedWells=returnsetting(InitialParameters, "Well range if constrained", "stringarray"); 
			Dialog.addChoice("First Row", WellRowOptions, ConstrainedWells[0]);
		    Dialog.addToSameRow();  Dialog.addChoice("First Column", WellColOptions, ConstrainedWells[2]);
		 Dialog.setInsets(0,0,5);    Dialog.addChoice("Last Row", WellRowOptions, ConstrainedWells[1]);
		    Dialog.addToSameRow(); Dialog.addChoice("Last Column", WellColOptions, ConstrainedWells[3]);
		  
		//Dialog.addMessage("Analysis of data by consecutive time windows",  FontSize, color1);
		  //WindowTimecourse=returnsetting(InitialParameters, "Analyse the data as consecutive time windows", "boolAsInt");
		  Dialog.addCheckbox("Analyse data as consecutive time windows",returnsetting(InitialParameters, "Analyse the data as consecutive time windows", "boolAsInt")); 
		  Dialog.addToSameRow(); Dialog.addCheckbox("MergeWindowFiles",returnsetting(InitialParameters, "Collate Merged Window Data", "boolAsInt"));
		   Dialog.addNumber("TimeWindowFirst" ,returnsetting(InitialParameters, "First timepoint to analyse if windowed", "int"));
		  //Dialog.addToSameRow();
		 Dialog.addToSameRow();
		 //Dialog.setInsets(0,0, 30); 
		 Dialog.addNumber("TimeWindowLast",returnsetting(InitialParameters, "Last timepoint to analyse if windowed", "int"));
		  Dialog.addToSameRow(); Dialog.addNumber("TimeWindowStep",returnsetting(InitialParameters, "Window width analysed in windows","int"));
		  
		//Dialog.addMessage("Analysis steps to run",  FontSize, color1);
		   Dialog.addCheckbox("Copy data from a predefined source",returnsetting(InitialParameters, "DataCopy", "boolAsInt"));
		   Dialog.addCheckbox("Preprocess (Background Subtract and Align)",returnsetting(InitialParameters, "Preprocess", "boolAsInt"));
		  Dialog.addToSameRow(); Dialog.addCheckbox("Save Merged Channels As AVI",returnsetting(InitialParameters, "option SaveMergedAsAVI", "boolAsInt"));
		   Dialog.addToSameRow();Dialog.addCheckbox("Segment and quantify ROIs" ,returnsetting(InitialParameters, "Segment","boolAsInt"));
		  Dialog.addToSameRow(); Dialog.addCheckbox("UseExistingROIs" ,returnsetting(InitialParameters, "option UseExistingROIs","boolAsInt"));
		  //Dialog.setInsets(0,20, 20); 
		  Dialog.addCheckbox("Collect Data from ROI-wise value tables" ,returnsetting(InitialParameters, "CollectData","boolAsInt"));
		  Dialog.addToSameRow(); Dialog.addCheckbox("Collate data from across plate as well-wise averages ",returnsetting(InitialParameters, "CollateData", "boolAsInt"));
		
		//Dialog.addMessage("Channel settings",  FontSize, color1);    
		  //Dialog.setInsets(0,0, 20); 
		  Dialog.addNumber("Analyse data as groups; Number" ,returnsetting(InitialParameters, "Number of Channel Groups", "int"));
		  GroupTypeOptions= newArray("none", "Row", "Column");
		   Dialog.addToSameRow(); Dialog.addChoice("GroupType",GroupTypeOptions, returnsetting(InitialParameters, "Group Type (if >1 group)", "string"));
		  
		
		  Dialog.addCheckbox("Explicity spell out complete channel names", returnsetting(InitialParameters, "Image filenames are explicity defined", "boolAsInt"));
		  		ImageKernels=returnsetting(InitialParameters, "ImageKernels", "stringarray"); 
		  Dialog.addToSameRow(); Dialog.addString("ImageKernels" ,String.join(ImageKernels, ","));
		  		SignalNamesRGBgroups=returnsetting(InitialParameters, "SignalNamesRGBgroups", "stringarray"); 
		  Dialog.addToSameRow(); Dialog.addString("SignalNamesRGBgroups" ,String.join(SignalNamesRGBgroups, ","), 20);
		  		RatioPairs=returnsetting(InitialParameters, "Calculate ratios of the following pairs,", "stringarray");
		  Dialog.addString("RatioPairs:" ,String.join(RatioPairs, ","));
		   		GeometricCorrection=returnsetting(InitialParameters, "Geometric Correction of channels", "values"); //int array
		  Dialog.addToSameRow();  Dialog.addString("GeometricCorrection:" ,String.join(GeometricCorrection, ","));
		  		
		  Dialog.addToSameRow(); Dialog.addNumber("Geometric Correction Factor" ,returnsetting(InitialParameters, "Geometric Distortion Correction Factor", "float"));
		  
		  Dialog.addNumber("CalciumChannel",returnsetting(InitialParameters, "CalciumChannel", "int"));
		  Dialog.addToSameRow(); Dialog.addNumber("CondenseFactor:",returnsetting(InitialParameters, "Ca images per pathway image","int"));
		  
		  InterburstAlignmentOptions=newArray("no", "pre", "post");
		  //Dialog.setInsets(0,20,20 );
		  Dialog.addChoice("InterburstAlignmentRef",InterburstAlignmentOptions, returnsetting(InitialParameters, "Align images either side of an addition point", "string"));
		   Dialog.addToSameRow(); Dialog.addNumber("CaFramespreAdd:" ,returnsetting(InitialParameters, "Ca Frames before the addition", "int"));
		  Dialog.addToSameRow();Dialog.addNumber("CaFramespostAdd:" ,returnsetting(InitialParameters, "Ca Frames after (must add up to value below)", "int"));
		  
		Dialog.setInsets(0,0, 5); Dialog.addMessage("Background, alignment and timecourse calibration settings",  FontSize, "008800");       
		   Dialog.addNumber("Background RB:",returnsetting(InitialParameters, "Preprocess RB", "int")); 
		   		AlignerChannelNumber= returnsetting(InitialParameters, "Align to channel", "int"); // need it later to form the paths as well
		  Dialog.addToSameRow(); Dialog.addNumber("AlignerChannelNumber:",parseInt(AlignerChannelNumber));
		  Dialog.addToSameRow(); Dialog.addCheckbox("AlignWithNanoJ", returnsetting(InitialParameters, "AlignWithNanoJ", "boolAsInt"));
		  
		  //Dialog.setInsets(0,0,20 );
		  Dialog.addNumber("BaselineReads:",returnsetting(InitialParameters, "Number of Time intervals as Baseline","int"));
		  Dialog.addToSameRow(); Dialog.addString("ImageTimeInterval:",returnsetting(InitialParameters, "Time inverval between pathway images", "string"));
		  
		Dialog.setInsets(0,0, 5); Dialog.addMessage("Segmentation settings",  FontSize, "008800");     
				SegmentationChannel=returnsetting(InitialParameters, "Segment on channel","int");// need it later to form the paths as well
		   Dialog.addNumber("SegmentationChannel:", parseInt(SegmentationChannel));
		   Dialog.addToSameRow(); Dialog.addNumber("ErodeCycles:", returnsetting(InitialParameters, "ErodeCycles","int"));
		   Dialog.addToSameRow(); Dialog.addNumber("MaxROIsPerField:", returnsetting(InitialParameters, "MaxROIsPerField","int")); 
		  
		   Dialog.addNumber("RB before sqrt if any:", returnsetting(InitialParameters, "RB before sqrt if any", "int"));
		   Dialog.addToSameRow(); Dialog.addNumber("Min. size:", returnsetting(InitialParameters, "Min size", "int"));
		   Dialog.addToSameRow(); Dialog.addNumber("Max. size:", returnsetting(InitialParameters, "Max size", "int"));
		    
		   		smoothingoptions=newArray("no smoothing", "median_radius3", "median_radius5");
		   Dialog.addChoice("AnalyseParticles option smoothing:", smoothingoptions,returnsetting(InitialParameters, "AnalyseParticles option smoothing", "string"));
		   Dialog.addToSameRow(); Dialog.addCheckbox("AnalyseParticles option watershed:", returnsetting(InitialParameters, "AnalyseParticles option watershed", "boolAsInt"));
		 
		    sqrtoptions = newArray("no", "default", "yes");   
		   Dialog.addChoice("SQRT pre-segmentation:", sqrtoptions, sqrtoptions[returnsetting(InitialParameters, "Square root (1 yes; -1 no; 0 default)","int")+1]); //no-default-yes have values -1, 0, +1, so need to add one to refer to it
		   		test=returnsetting(InitialParameters, "Segmentation Method (StarDist or AnalyseParticles)","string");
		   		entry = (test=="StarDist");
		   Dialog.addToSameRow(); Dialog.addCheckbox("UseStarDist", entry);
		
		  
		  Dialog.addCheckbox("Modify band compartment width from default", returnsetting(InitialParameters, "Modify band compartment width from default", "boolAsInt"));
		  Dialog.addToSameRow(); Dialog.addNumber("Width of Band:", returnsetting(InitialParameters, "Width of Band", "int"));
		  Dialog.addToSameRow(); Dialog.addCheckbox("Use algorithm to prevent overlap between bands (experimental)", returnsetting(InitialParameters, "Use algorithm to prevent overlap between bands (experimental)", "boolAsInt"));
		
		Dialog.setInsets(0,0, 5); Dialog.addMessage("Signal Threshold settings",  FontSize, "008800");    
				Threshold_AbsoluteMin=returnsetting(InitialParameters, "Threshold_AbsoluteMin by channel", "value(s)"); //array
				Threshold_AbsoluteMax=returnsetting(InitialParameters, "Threshold_AbsoluteMax by channel", "value(s)"); //array
				Threshold_AverageMin=returnsetting(InitialParameters, "Threshold_AverageMin by channel", "value(s)"); //array
				Threshold_AverageMax=returnsetting(InitialParameters, "Threshold_AverageMax by channel", "value(s)"); //array
		  Dialog.addString("Threshold_AbsoluteMin:",String.join(Threshold_AbsoluteMin, ","));
		  Dialog.addToSameRow(); Dialog.addString("Threshold_AbsoluteMax:",String.join(Threshold_AbsoluteMax, ","), 16);
		  Dialog.addString("Threshold_AverageMin:",String.join(Threshold_AverageMin, ","));
		  Dialog.addToSameRow();Dialog.addString("Threshold_AverageMax:" ,String.join(Threshold_AverageMax, ","),16);
		  //Dialog.addMessage("Threshold_AverageMax:" +String.join(Threshold_AverageMax, ","),  FontSize, color1);      
		 
				
				Channels = ImageKernels.length;
				//define ThresholdCode even if not used in this specific run, so that it is recorded //if (CollectData | CollateData|(MergeWindowFiles && WindowTimecourse))//
				if ((Threshold_AbsoluteMin.length!=Channels)||(Threshold_AbsoluteMax.length!=Channels)||(Threshold_AverageMin.length!=Channels)||(Threshold_AverageMax.length!=Channels))
					print("WARNING - Thresholds and Channel count do not match");
					
				//if ((Threshold_AbsoluteMin.length<Channels)||(Threshold_AbsoluteMax.length<Channels)||(Threshold_AverageMin.length<Channels)||(Threshold_AverageMax.length<Channels)) 
				//	FatalError("Insufficient thresholds defined for channels used - aborting");
				Threshold_AbsoluteMin= Array.trim(Threshold_AbsoluteMin, Channels);
				Threshold_AbsoluteMax= Array.trim(Threshold_AbsoluteMax, Channels);
				Threshold_AverageMin= Array.trim(Threshold_AverageMin, Channels);
				Threshold_AverageMax= Array.trim(Threshold_AverageMax, Channels);
				//ThresholdCode="Threshold"+replace(array2str(Array.concat(Threshold_AbsoluteMin, Threshold_AbsoluteMax, Threshold_AverageMin, Threshold_AverageMax)), ",", "");
				ThresholdArray = Array.concat(Threshold_AbsoluteMin, Threshold_AbsoluteMax, Threshold_AverageMin, Threshold_AverageMax);//and length 4* Channels
				ThresholdCode = "Threshold"; for(i=0;i<ThresholdArray.length; i++) {ThresholdCode+=toString(parseInt(ThresholdArray[i]));} //"Min"+MinThreshold+"Max"+MaxThreshold+"Avg"+"_"+NonSegmentationImages[0]+AvgThresholdMinChannel0+"-"+AvgThresholdMaxChannel0+"_"+NonSegmentationImages[1]+AvgThresholdMinChannel1+"-"+AvgThresholdMaxChannel1;
				AlignmentFolder="ImagesAlignedtoCh"+AlignerChannelNumber;
				SegmentationFolder = "SegmentationData_A" + AlignerChannelNumber+ "S" + SegmentationChannel; //options "" or some name (use the same all the time)
		  		OutputFolderKernel = "CollatedData_A" + AlignerChannelNumber+ "S" + SegmentationChannel+"_";
				OutputFolder = OutputFolderKernel + ThresholdCode;
			Message="Aligned Image Folder  " +AlignmentFolder;
			Message=Message + "          " + "Segmentation Folder  " +SegmentationFolder;
			Message=Message +  "          " + "Analysis Output Folder  " +OutputFolder;
			Dialog.setInsets(5,0, 0);  Dialog.addMessage(Message, FontSize, "000088");  

		  Dialog.setInsets(0,0, 5);  Dialog.addMessage("Colour mapping to channels as follows", FontSize, "880000");
		  //Dialog.addString("colour mapping to first 8 channels" ,String.join(colour, ","));
		  colorchoice=newArray("blue", "green", "red", "grey", "cyan", "magenta", "yellow", "black");
		  colour=returnsetting(InitialParameters, "colour mapping to first 8 channels", "value(s)"); // //int array
		   Dialog.addChoice("Ch0", colorchoice, colorchoice[0]);
		   Dialog.addToSameRow(); Dialog.addChoice("Ch1", colorchoice, colorchoice[1]);
		   Dialog.addToSameRow(); Dialog.addChoice("Ch2", colorchoice, colorchoice[2]);
		   Dialog.addChoice("Ch3", colorchoice, colorchoice[3]);
		   Dialog.addToSameRow(); Dialog.addChoice("Ch4", colorchoice, colorchoice[4]);
		   Dialog.addToSameRow(); Dialog.addChoice("Ch5", colorchoice, colorchoice[5]);
		   Dialog.addChoice("Ch6", colorchoice, colorchoice[6]);
		   Dialog.addToSameRow(); Dialog.addChoice("Ch7", colorchoice, colorchoice[7]);
		Dialog.show();
		
		
		//First collect choices
		
		newParameterLines= newArray(100); //need 68 + 1 to pass changes
		R0= Dialog.getChoice();C0= Dialog.getChoice();
		R1= Dialog.getChoice();C1= Dialog.getChoice();
		newParameterLines[10]= "10,Well range if constrained" + ","+ R0 + "," + R1 + "," + C0 + "," + C1;
		newParameterLines[26]= "26,Group Type (if >1 group)," +Dialog.getChoice();
		newParameterLines[33]= "33,Align images either side of an addition point," +Dialog.getChoice();
		newParameterLines[52]= "52,AnalyseParticles option smoothing," +Dialog.getChoice();
			test=Dialog.getChoice(); 
			for (i=0; i<sqrtoptions.length; i++) if (test==sqrtoptions[i]) {entry=i-1; i=sqrtoptions.length;}
		newParameterLines[54]= "54,Square root (1 yes; -1 no; 0 default)," + entry;
		
		
		newParameterLines[67]= "67,colour mapping to first 8 channels";
		for (i=0; i< 8; i++) 
			{
			entry=Dialog.getChoice();
			for (j=0; j<colorchoice.length; j++) 
				{
				if (entry==colorchoice[j]) 
					{
					newParameterLines[67]=newParameterLines[67]+","+j; 
					j =colorchoice.length;
					}
				}
			}
	
	 
		
		//this section pares any extra spaces off the sends of each string, including comma-delimited string arrays
		newParameterLines[2]= "2,RunList," + csvTrim(Dialog.getString());
		newParameterLines[3]= "3,Disk," + csvTrim(Dialog.getString());
		newParameterLines[4]= "4,datapath," + csvTrim(Dialog.getString());
		newParameterLines[5]= "5,user_ID," + csvTrim(Dialog.getString());
		newParameterLines[6]= "6,experiment_ID," + csvTrim(Dialog.getString());
			ImageKernels=split(csvTrim(Dialog.getString()), ","); // need it again below
		newParameterLines[27]= "27,ImageKernels," + String.join(ImageKernels, ",");
			SignalNamesRGBgroups= split(csvTrim(Dialog.getString()), ",");  //as string here, need it again below
		newParameterLines[29]= "29,SignalNamesRGBgroups," + String.join(SignalNamesRGBgroups,",");
		newParameterLines[40]= "40,Calculate ratios of the following pairs," + csvTrim(Dialog.getString());
		newParameterLines[30]= "30,Geometric Correction of channels," + csvTrim(Dialog.getString());
				ImageTimeInterval=Dialog.getString(); //need it again below
		newParameterLines[38]= "38,Time inverval between pathway images," + ImageTimeInterval;
		newParameterLines[61]= "61,Threshold_AbsoluteMin by channel," + csvTrim(Dialog.getString());
		newParameterLines[62]= "62,Threshold_AbsoluteMax by channel," + csvTrim(Dialog.getString());
		newParameterLines[63]= "63,Threshold_AverageMin by channel," + csvTrim(Dialog.getString());
		newParameterLines[64]= "64,Threshold_AverageMax by channel," + csvTrim(Dialog.getString());
		
		
		newParameterLines[12]= "12,First timepoint to analyse if windowed," + parseInt(Dialog.getNumber());
		newParameterLines[13]= "13,Last timepoint to analyse if windowed," +  parseInt(Dialog.getNumber());
		newParameterLines[14]= "14,Window width analysed in windows," +  parseInt(Dialog.getNumber());
		newParameterLines[25]= "25,Number of Channel Groups," + parseInt(Dialog.getNumber());
		newParameterLines[31]= "31,Geometric Distortion Correction Factor," +  Dialog.getNumber(); //not an integer! but code will flag a  difference between 1.0 and 1 -> trim it?
		newParameterLines[32]= "32,CalciumChannel," +  parseInt(Dialog.getNumber());
			CondenseFactor=parseInt(Dialog.getNumber()); // need it again below
		newParameterLines[36]= "36,Ca images per pathway image," + CondenseFactor;
		newParameterLines[34]= "34,Ca Frames before the addition," +  parseInt(Dialog.getNumber());
		newParameterLines[35]= "35,Ca Frames after (must add up to value below)," +  parseInt(Dialog.getNumber());
		newParameterLines[41]= "41,Preprocess RB," +  parseInt(Dialog.getNumber());
		newParameterLines[44]= "44,Align to channel," +  parseInt(Dialog.getNumber());
		newParameterLines[37]= "37,Number of Time intervals as Baseline," + parseInt(Dialog.getNumber());
		newParameterLines[56]= "56,Segment on channel," + parseInt(Dialog.getNumber());
		newParameterLines[59]= "59,ErodeCycles," + parseInt(Dialog.getNumber());
		newParameterLines[60]= "60,MaxROIsPerField," + parseInt(Dialog.getNumber());
		newParameterLines[49]= "49,RB before sqrt if any," + parseInt(Dialog.getNumber());
		newParameterLines[50]= "50,Min size," + parseInt(Dialog.getNumber());
		newParameterLines[51]= "51,Max size," + parseInt(Dialog.getNumber());
		newParameterLines[68]= "68,Width of Band," + parseInt(Dialog.getNumber());	   
		  
		
		newParameterLines[9]= "9,Constrain Wells," + bool2str(Dialog.getCheckbox());  
		newParameterLines[11]= "11,Analyse the data as consecutive time windows," +  bool2str(Dialog.getCheckbox()); 
		newParameterLines[15]= "15,Collate Merged Window Data," +  bool2str(Dialog.getCheckbox()); 
		newParameterLines[17]= "17,DataCopy," + bool2str(Dialog.getCheckbox());  
		newParameterLines[18]= "18,Preprocess," + bool2str(Dialog.getCheckbox());  
		newParameterLines[19]= "19,option SaveMergedAsAVI," + bool2str(Dialog.getCheckbox());  
		newParameterLines[20]= "20,Segment," + bool2str(Dialog.getCheckbox());  
		newParameterLines[21]= "21,option UseExistingROIs," + bool2str(Dialog.getCheckbox());  
		newParameterLines[22]= "22,CollectData," + bool2str(Dialog.getCheckbox());  
		newParameterLines[23]= "23,CollateData," + bool2str(Dialog.getCheckbox()); 
		newParameterLines[28]= "28,Image filenames are explicity defined," +  bool2str(Dialog.getCheckbox());  
		newParameterLines[46]= "46,AlignWithNanoJ," +  bool2str(Dialog.getCheckbox());  
		newParameterLines[53]= "53,AnalyseParticles option watershed," + bool2str(Dialog.getCheckbox());  
		if(Dialog.getCheckbox()== true) SegmentationMethod= "StarDist"; else SegmentationMethod= "AnalyseParticles";  
			newParameterLines[55]= "55,Segmentation Method (StarDist or AnalyseParticles)," +SegmentationMethod;  
		newParameterLines[69]= "69,Modify band compartment width from default," + bool2str(Dialog.getCheckbox());  
		newParameterLines[70]= "70,Use algorithm to prevent overlap between bands (experimental)," + bool2str(Dialog.getCheckbox()); 
		
				
		  
		// fill in the  fixed ones
		newParameterLines[0] = ",Parameter, Value [any value for a parameter name in square brackets cannot be read in]";
		newParameterLines[16]="16,[Activities selected],see below";
		newParameterLines[24]="24,[Channels],see below";
		newParameterLines[42]="42,[AlignmentSettings],see below"; 
		newParameterLines[48]="48,[SegmentationSettings],see below"; 
		// fill in the lines based on other values		
		if (CondenseFactor!=0)	{
			newParameterLines[39]="39,[Time inverval between calcium images],"+ parseInt(ImageTimeInterval)/CondenseFactor; 
		}
		else newParameterLines[39]="39,[Time inverval between calcium images],NaN";
		
		AlignerChannelNumber= returnsetting(newParameterLines, "Align to channel", "int"); //update this v<lue
		entry= (AlignerChannelNumber!=-1);
		newParameterLines[43]="43,Channels and timepoints will be aligned," + bool2str(entry);
			if (AlignerChannelNumber>0)
				{
				if (AlignerChannelNumber>ImageKernels.length) entry= "invalid alignment channel"; 	
				else entry ="prefix="+ImageKernels[AlignerChannelNumber-1] +" for "+SignalNamesRGBgroups[AlignerChannelNumber-1]; 
				}
				else if (AlignerChannelNumber==0) entry= "independent alignment"; 
				else entry ="channels will not be aligned";	 //if select "-1" [this will happen if NaN like " ", but will crash?]
		newParameterLines[45]="45,[this is],prefix="+ entry;
		
		SegmentationChannel= returnsetting(newParameterLines, "Segment on channel", "int"); //update this v<lue
		newParameterLines[47]="47,[Folder with Aligned Merged data],"+ AlignmentFolder;
			if (SegmentationChannel>0)
				{
				if (SegmentationChannel>ImageKernels.length) entry= "invalid segmentation channel"; // something wrong, will ask user to fix
				else entry= ImageKernels[SegmentationChannel-1] +" for "+SignalNamesRGBgroups[SegmentationChannel-1]; 
				}
			else entry="no segmentation";  // if select "-1" [this will happen if NaN like " ", but will crash?] 
		newParameterLines[57]="57,[this is],prefix="+ entry;
		newParameterLines[58]="58,[SegmentationSettings],"+ SegmentationFolder;
		newParameterLines[65]="65,[Output folder kernel],"+ OutputFolderKernel;
		newParameterLines[66]="66,[Data output folder],"+ OutputFolderKernel+ThresholdCode;
		// note if channel#s set outside of range this will crash - could put a safety feature in the dialog function?

		
		
		changes=0;
		//print(changes);
		NonEditableLines= ",0,1,7,8,16,24,39,42,43,45,47,48,57,58,65,66,"; //each flanked with commas for specific search
		
		for (i=0;i<InitialParameters.length-1; i++) //exclude entry 68 which indicates a change
		{
		if (indexOf(NonEditableLines, ","+i+",") ==-1)
			{
				//print(i, InitialParameters[i]);		print(i, newParameterLines[i]);
				if (InitialParameters[i] !=newParameterLines[i]) {changes ++; print(i + " has changed");}
			}
		}
		
		//check again the band width and channel count parameters to see if they match 
		if (changes==0) 
			{
			print("checking BandWidth");
			if (!checkBandWidth(InitialParameters, "silent")) changes = -1; //ensure a return to fix it
			print("changes"+changes);
			}
		
		ImageKernels=returnsetting(InitialParameters, "ImageKernels", "stringarray"); 
		if (changes==0) 
			{
			print("checking Param count");
			if (!checkChannelParameterCount(InitialParameters, "silent",ImageKernels.length)) changes = -1; //ensure a return to fix it
			print("changes to confirm (or to make) "+changes);
			}
		
		if (changes==0) 
			{
			print("checking Channel counts");
			if (!checkChannelNumbers(InitialParameters, "silent",ImageKernels.length)) changes = -1; //ensure a return to fix it
			print("changes to confirm (or to make) "+changes);
			}
		
			
		//print(changes);
		newParameterLines[100]=changes;
		
		return newParameterLines;
		
		// done with editable settings
		}
		
function csvTrim(string)
		{
		array = split(string, ","); 
		for (i=0; i< array.length; i++) 
			array[i]=String.trim(array[i]);
		string = String.join(array, ","); //default introduces a space as well
		return string ;
		}

//**************************************************************
//MAIN starts here


//make sure no stray images are open that could be confused with newly generated ones
//run("Close All");  generates an error if there are none > better way? try this
list = getList("window.titles");  for (i=0; i<list.length; i++){ selectWindow(list[i]); if(list[i]!="Macro.txt") run("Close");}
if(isOpen("Log")) close("Log"); //print("\\Clear");
call("java.lang.System.gc"); //garbage collector
print("\\Clear");
 	
// First, get the parameters to be used for the analysis
if (!ReadSettingsFromFile) settinglines=ParametersFromMacro();	// get initial settings  from the macro function above
else //read initial settings from the defined file
	{	
	//READ IN ALL VALUES
	ParameterFile=SettingsPath+SettingsFilename;
	if (!File.exists(ParameterFile)) FatalError("Settings file "+ ParameterFile  + " does not exist. \n Please check your settings");	
	settings= File.openAsString(ParameterFile);
	settinglines=split(settings,"\n");
	}

// 	now  show parameters and allow changes via a dialog. Note one analysis can process multiple experiments consecutively
ConfirmChanges=-1; //this means show parameters to give opportunity to change
settinglines[100]=ConfirmChanges; // need to pass the change status
//update settings until no more changes AND the channel parameters match the channel count
// this means if there are !=0 changes, we always request a confirmation
do settinglines=parameterDisplay(settinglines); while  (settinglines[100] !=0) ;

print("Settings100 is "+settinglines[100]);
// Now we have the parameters confirmed, we can proceed 

//Validate experiment parent folder exists 
	DiskWithData=returnsetting(settinglines, "Disk",  "string");
	datapath=returnsetting(settinglines, "datapath",  "string");
	user_ID=returnsetting(settinglines, "user_ID",  "string");
	experiment_ID=returnsetting(settinglines, "experiment_ID",  "string");
pathforanalysis =DiskWithData + File.separator + datapath + user_ID  + File.separator+ experiment_ID  + File.separator;
if (!File.exists(pathforanalysis)) FatalError("The general path " + pathforanalysis +  "does not exist. Please check parameters entered.");


//set up some parameters to be updated or reformatted and saved runtime
var CurrentRunDateStamp=DateStampstring();


//set all values
RunList= returnsetting(settinglines, "RunList", "stringarray");
	// Clean up RunList
	// this line needs IJ 1.52s or later 
	for (i=0; i<lengthOf(RunList); i++) RunList[i] = String.trim(RunList[i]); //trim spaces from ends but spaces now allowed within name

//fill out lines that were not set by the dialog
settinglines[1]= "1,[Generated by Macro Version:],"+VersionNumber;
settinglines[7]="7,[Datestamp],"+CurrentRunDateStamp;
settinglines[8]="8,[CurrentRun],"+RunList[0]; //will be updated for each expt processed


// pass the Parameter string array to the function to set the values 


ConstrainWells=returnsetting(settinglines, "Constrain Wells", "boolAsInt"); 
ConstrainedWells=returnsetting(settinglines, "Well range if constrained", "stringarray"); 
WindowTimecourse=returnsetting(settinglines, "Analyse the data as consecutive time windows", "boolAsInt"); 
TimeWindowFirst=returnsetting(settinglines, "First timepoint to analyse if windowed", "int");
TimeWindowLast=returnsetting(settinglines, "Last timepoint to analyse if windowed", "int");
TimeWindowStep=returnsetting(settinglines, "Window width analysed in windows","int");
MergeWindowFiles=returnsetting(settinglines, "Collate Merged Window Data", "boolAsInt"); 
DataCopy=returnsetting(settinglines, "DataCopy", "boolAsInt"); 
Preprocess=returnsetting(settinglines, "Preprocess", "boolAsInt"); 
SaveMergedAsAVI=returnsetting(settinglines, "option SaveMergedAsAVI", "boolAsInt"); 
Segment=returnsetting(settinglines, "Segment","boolAsInt"); 
UseExistingROIs=returnsetting(settinglines, "option UseExistingROIs","boolAsInt"); 
CollectData=returnsetting(settinglines, "CollectData","boolAsInt"); 
CollateData=returnsetting(settinglines, "CollateData", "boolAsInt"); 
GroupCount=returnsetting(settinglines, "Number of Channel Groups", "int");
GroupType=returnsetting(settinglines, "Group Type (if >1 group)", "string");
ImageKernels=returnsetting(settinglines, "ImageKernels", "stringarray"); 
ChannelNames_explicit=returnsetting(settinglines, "Image filenames are explicity defined", "boolAsInt"); 
SignalNamesRGBgroups=returnsetting(settinglines, "SignalNamesRGBgroups", "stringarray"); 
GeometricCorrection=returnsetting(settinglines, "Geometric Correction of channels", "values"); //int array
GeometricDistortionCorrectionFactor=returnsetting(settinglines, "Geometric Distortion Correction Factor", "float");  
CalciumChannel=returnsetting(settinglines, "CalciumChannel", "int");
InterburstAlignmentRef=returnsetting(settinglines, "Align images either side of an addition point", "string"); 
CaFramespreAdd=returnsetting(settinglines, "Ca Frames before the addition", "int");
CaFramespostAdd=returnsetting(settinglines, "Ca Frames after (must add up to value below)", "int"); //   Ca Frames after (must add up to value below)
CondenseFactor=returnsetting(settinglines, "Ca images per pathway image","int");
BaselineReads=returnsetting(settinglines, "Number of Time intervals as Baseline","int");
ImageTimeInterval=returnsetting(settinglines, "Time inverval between pathway images", "string");
RatioPairs=returnsetting(settinglines, "Calculate ratios of the following pairs,", "stringarray");
	if (RatioPairs.length !=0) if (RatioPairs[0]=="") RatioPairs=newArray(); //make sure RatioPairs.length = 0 if it is blank
RB=returnsetting(settinglines, "Preprocess RB", "int");
AlignerChannelNumber=returnsetting(settinglines, "Align to channel", "int");
AlignWithNanoJ=returnsetting(settinglines, "AlignWithNanoJ", "boolAsInt"); 
SegmentationSettings = newArray(6);
SegmentationSettings[0]=returnsetting(settinglines, "RB before sqrt if any", "int"); 
SegmentationSettings[1]=returnsetting(settinglines, "Min size", "int");
SegmentationSettings[2]=returnsetting(settinglines, "Max size", "int");
SegmentationSettings[3]=returnsetting(settinglines, "AnalyseParticles option smoothing", "string");
SegmentationSettings[4]=returnsetting(settinglines, "AnalyseParticles option watershed", "boolAsInt"); 
SegmentationSettings[5]=returnsetting(settinglines, "Square root (1 yes; -1 no; 0 default)","int");
	teststring=returnsetting(settinglines, "Segmentation Method (StarDist or AnalyseParticles)","string");
UseStarDist=(teststring=="StarDist"); 

//new settable parameters here
ModifyWidthOfBand=returnsetting(settinglines, "Modify band compartment width from default","boolAsInt");
if (ModifyWidthOfBand)
	BandWidth=returnsetting(settinglines, "Width of Band", "int");
else BandWidth= DefaultValueForParameter("Width of Band");
NoOverlapBandAlgorithm=returnsetting(settinglines, "Use algorithm to prevent overlap between bands (experimental)","boolAsInt");


SegmentationChannel=returnsetting(settinglines, "Segment on channel","int");
ErodeCycles=returnsetting(settinglines, "ErodeCycles","int");
MaxROIsPerField=returnsetting(settinglines, "MaxROIsPerField","int");
Threshold_AbsoluteMin=returnsetting(settinglines, "Threshold_AbsoluteMin by channel", "value(s)"); //array
Threshold_AbsoluteMax=returnsetting(settinglines, "Threshold_AbsoluteMax by channel", "value(s)"); //array
Threshold_AverageMin=returnsetting(settinglines, "Threshold_AverageMin by channel", "value(s)"); //array
Threshold_AverageMax=returnsetting(settinglines, "Threshold_AverageMax by channel", "value(s)"); //array

colour=returnsetting(settinglines, "colour mapping to first 8 channels", "value(s)"); // //int array

//************below is repeated in functions, but we also need it here
OutputFolderKernel = "CollatedData_A" + AlignerChannelNumber+ "S" + SegmentationChannel+"_";
Channels = ImageKernels.length;
//define ThresholdCode even if not used in this specific run, so that it is recorded //if (CollectData | CollateData|(MergeWindowFiles && WindowTimecourse))//
if ((Threshold_AbsoluteMin.length!=Channels)||(Threshold_AbsoluteMax.length!=Channels)||(Threshold_AverageMin.length!=Channels)||(Threshold_AverageMax.length!=Channels)) 
	print("WARNING - Thresholds and Channel count do not match");

Threshold_AbsoluteMin= Array.trim(Threshold_AbsoluteMin, Channels);
Threshold_AbsoluteMax= Array.trim(Threshold_AbsoluteMax, Channels);
Threshold_AverageMin= Array.trim(Threshold_AverageMin, Channels);
Threshold_AverageMax= Array.trim(Threshold_AverageMax, Channels);
//ThresholdCode="Threshold"+replace(array2str(Array.concat(Threshold_AbsoluteMin, Threshold_AbsoluteMax, Threshold_AverageMin, Threshold_AverageMax)), ",", "");
ThresholdArray = Array.concat(Threshold_AbsoluteMin, Threshold_AbsoluteMax, Threshold_AverageMin, Threshold_AverageMax);//and length 4* Channels
ThresholdCode = "Threshold"; for(i=0;i<ThresholdArray.length; i++) {ThresholdCode+=toString(parseInt(ThresholdArray[i]));} //"Min"+MinThreshold+"Max"+MaxThreshold+"Avg"+"_"+NonSegmentationImages[0]+AvgThresholdMinChannel0+"-"+AvgThresholdMaxChannel0+"_"+NonSegmentationImages[1]+AvgThresholdMinChannel1+"-"+AvgThresholdMaxChannel1;
AlignmentFolder="ImagesAlignedtoCh"+AlignerChannelNumber;
SegmentationFolder = "SegmentationData_A" + AlignerChannelNumber+ "S" + SegmentationChannel; //options "" or some name (use the same all the time)

//Array.print(ThresholdArray);//DEBUG
//************end repeat



// the following lines can only be added here

// whether values were set above or read from file, the following is carried out to save the current file
// record parameters to file in experiment parent folder and copy once per experiment, here is the first one, outside the loop, so it can be copied later
// record the settings that are used with a unique time stamp
ParameterFile =pathforanalysis+"Analysis_"+RunList[0]+"_"+CurrentRunDateStamp+".csv";
File.saveString(String.join(settinglines,"\n"), ParameterFile); 
print("Current Parameters saved at:");
print(ParameterFile); //can double click this in log file to open it

// compatibility check
IJVersionRequirement = "IJ 1.52s"; //"IJ 1.51w";
IJFailVersion ="1.51g";
IJVersionRunning = IJ.getFullVersion;


//collect records of macro usage to hard-coded location to assist debugging
	header = "Data stamp, User, Macro, Version, IJ version, Parameter File \n";
	recordFilename= DiskWithData + File.separator + datapath + "AnalysisMacroUseRecord.csv";
	if (!File.exists(recordFilename))  File.saveString(header, recordFilename);
	username= exec("cmd /c whoami"); //this comes with \n to be trimmed off below
	newLine= CurrentRunDateStamp+","+ substring(username, 0, lengthOf(username)-1) + "," + "AnalysisMacro" + "," + VersionNumber + ","+ IJVersionRunning + "," +ParameterFile;
	do {wait(50); print("waiting to generate Macro Use record");} while (!File.exists(recordFilename)) 
	File.append(newLine, recordFilename);


// lines saved are the ones used to set the parameters 
//i) script alwasy runs with recorded machine-read settings
//ii) to allow reuse of settings
//iii) so the array of lines that can be passed between functions to simplify the function argument list




// report settings in log 
for (i=0;i<settinglines.length-1; i++) print(settinglines[i]);
print("End of parameters saved to disk *********************************************************************************");
print("\n\n");

print("Running IJ version " + IJVersionRunning);	
print("REQUIRES version "+ IJVersionRequirement + "; it will fail with version "+ IJFailVersion);
print("For Fiji, Cookbook plugin is required");
print("Now option to use NanoJ-based alignment, requires file Fast4DReg_-2.0.0-jar-with-dependencies.jar in plugins");
print("Script Version "+VersionNumber);
print("This macro is set for " + CondenseFactor + " Calcium images per KTR image. If this is not correct, the macro will fail");
print("Rolling ball background subtraction is currently at  " + RB);
print("Align channel and segmentation channel selected are " + AlignerChannelNumber, SegmentationChannel);
print("Align with NanoJ is "+ AlignWithNanoJ);
//print("Parameter options selected: " + ExperimentType);
print("");

			
//Validation of settings
//Aligner settings
if(AlignerChannelNumber==-1)  AlignTimepoints= false;
else AlignTimepoints=true;


if (AlignerChannelNumber>ImageKernels.length) 
	FatalError("Input error - Alignment channel ("+ AlignerChannelNumber+ ") > total number of channels (" + ImageKernels.length + ").\n Did you forget to specify some channels?"); 
	
if (SegmentationChannel>ImageKernels.length)
	FatalError("Input error - Segmentation channel ("+ SegmentationChannel+ ") > total number of channels (" + ImageKernels.length + ").\n Did you forget to specify some channels?"); 
	

if (SignalNamesRGBgroups.length/GroupCount>ImageKernels.length) 
		FatalError("Input error - number of Signal Names per group("+ SignalNamesRGBgroups.length/GroupCount+ ") must match number of image types (" + ImageKernels.length + ").\n Please check channel names"); 
	
	
	
	
if (!ChannelNames_explicit)	
	{//this flag means the Imagekernels should be rewritten for each experiments based on originals provided, stored here as hints 
	ImageKernelhints= ImageKernels;  //once before expt loop. Take care function does not rewrite array even under different name, it's a pointer
	}
	
// Imagename kernels to be coded as RGB, ordered by datatype 1, 2, 3...
//"None" only permitted for B channel. If not none, this one of the will get condensed, presumed the Ca one. If there are only 2 channels "None" is better than repeating one
// QUESTION: is this old? Single channel is allowed now, isn't it?
if(Verbosity >1) 
		printformatter ="-"; //accumulates output
	else
		printformatter = "\\Update:"; //updates output line
	


if(AlignmentFolder!="")  {temp=AlignmentFolder; AlignmentFolder= temp+File.separator; }//so can add to the path it even if it is ""

if(!ConstrainWells) 
{FirstRow="A"; LastRow="P"; FirstColumn=1; LastColumn=24;}
else
{FirstRow=ConstrainedWells[0]; LastRow=ConstrainedWells[1]; FirstColumn=parseInt(ConstrainedWells[2]); LastColumn=parseInt(ConstrainedWells[3]);}


// set some variables global
var compartment = newArray("nuc", "band");  // code is designed around this. Some changes needed if this is modified
var parameters_collected_per_channel=6; //this is cyt, nuc, cytbynuc and Norm versions of each

if((WindowTimecourse) *(BaselineReads>TimeWindowStep))
	{BaselineReads=TimeWindowStep; //BaselineReads>TimeWindowStep is not possible to interpret
	print("WARNING: Corrected Baseline read setting so that it does not exceed Window duration");}

 baselinetimepoints = CondenseFactor*BaselineReads;

//need a temp directory to store local alignment matrixes locally so we can use multiple computers to run the macro
var tmppath = getDirectory("temp");
if (tmppath=="")       exit("No windows temp directory available on this computer. This has to be corrected to use this macro, or another computer will overwrite settings during the run!");
  


//Copy Data if selected
if(DataCopy==true) //should this be for all expts first like now or one at a time? It is a bit slow
{
for (i=0; i<RunList.length; i++)
	{
	dir_source = "X" + substring(pathforanalysis + RunList[i] , 1);
	dir_target="Y" + substring(pathforanalysis + RunList[i]  , 1);
	if(!File.exists(dir_target)) File.makeDirectory(dir_target);
	print("xcopy",  "\"" + dir_source + "\"", "\"" + dir_target+ "\"", "/E/Y" );
	exec("xcopy",  "\"" + dir_source + "\"", "\"" + dir_target+ "\"", "/E/Y" );
	}
print("DataCopy done");
}



datestamp0= split(getDateStamp(), "-"); // this is for a timing report
for (i=0; i<settinglines.length-1; i++) { if(indexOf(settinglines[i], "[CurrentRun]") !=-1) {LineWithCurrentRun =i; i=settinglines.length;}}

print(fromCharCode(13)+ "The following runs are specified for analysis");
Array.print(RunList);
print(fromCharCode(13)+fromCharCode(13));//\n\n


//loop through all runs selected´, check existence and proceed
for (CurrentRun=0; CurrentRun<RunList.length; CurrentRun++) 
	{
	Currentexperimentpath= pathforanalysis+ RunList[CurrentRun]  + File.separator;
	if (CurrentRun!=0) // if after 1st experiment analysis, copy parameter file describing this experiment analysis, even if there's an error, so we can see why
		{
		ParameterFile=pathforanalysis+"Analysis_"+RunList[CurrentRun]+"_"+CurrentRunDateStamp+".csv"; //updating the analysis parameter record
		settinglines[LineWithCurrentRun]= toString(LineWithCurrentRun)+",CurrentRun,"+RunList[CurrentRun]; // setting current run in  8 (could have searched for "CurrentRun" and returned the index )
		File.saveString(String.join(settinglines, "\n"), ParameterFile);
		}
	if (!File.exists(Currentexperimentpath))
			{
			errorstring = "The experiment path " + Currentexperimentpath +  "does not exist. Please check parameters entered";
			print("Error: " + errorstring);
			File.append("ErrorReport-" + DateStampstring() + errorstring, pathforanalysis+"error.log"); 
			}
			else
			{
			AnalyseCurrentRun(Currentexperimentpath, CurrentRunDateStamp, settinglines);
			}
	if (CurrentRun <RunList.length -1) print("Seeking next experiment.");
	}


print(fromCharCode(13)+fromCharCode(13));
print("Macro '"+VersionNumber+ "' Completed");	
datestamp1= split(getDateStamp(), "-");
dhour=24*(0+datestamp1[2]-datestamp0[2]) + (0+datestamp1[3]-datestamp0[3]) + (0+datestamp1[4]-datestamp0[4])/60 + (0+datestamp1[5]-datestamp0[5])/3600;
//getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
//dhour=24*(dayOfMonth-dayOfMonth0)+(hour-hour0) + (minute-minute0)/60 + (second-second0)/3600;
print("That took " + dhour*60 + " minutes");
//selectWindow("Log"); setLocation(screenWidth/2, screenHeight/2, screenWidth/4, screenHeight/8);	 does not work 
//if (isOpen("Macro.txt")) setLocation(screenWidth/2, screenHeight/2, screenWidth/8, screenHeight/4);	
//***************************end MAIN of Macro







function array2str(a)
{
if (a.length ==0) return "";	
str= toString(a[0]); 
for (i=1;i <a.length; i++) str=str + "," + toString(a[i]);
return str;
}

function array2lines(a)
{str=""; 
for (i=0;i <a.length; i++) str=str +  toString(a[i])+"\n";
return str;
}


function bool2str(x)
{if (x==1) return "true";
else return "false";}

function str2bool(x)
{if (x=="true") return 1;
else return 0}




function DefaultValueForParameter(L_key)
{
//this function fills in when want to add a new parameter or perhaps the selected parameter file was corrupted?
//will expand this as needed
if (L_key=="Width of Band") return "1";
if (L_key=="Modify band compartment width from default") return "false";
if (L_key=="Use algorithm to prevent overlap between bands (experimental)") return "false";

}


function returnsetting(settings, key, returntype) // type = "linenumber", "linecontent", "value", "values" last two both get an array length 1 or more
{
//print(key, returntype);

// just added a new setting "Width of Band", if it is not found, offer a default =1
a1=Array.filter(settings, key);
//provide a default value if there is no return (line numbers will be fixed later)

if (a1.length==0) 
{
print(String.join(settings, "\n"));
print(key);
a1 = newArray("0,"+key+","+ DefaultValueForParameter(key));
}

if (returntype=="linecontent") return split(a1[0], ","); //array of strings for whole line. Assumption here is there is only a single match to the key
a2=a1[0];// line number


if (returntype=="linenumber") return a1[0]; //integer
a3= split(a2, ","); // line as an array of strings, min 3 elements
value = newArray(a3.length-2);
if (a3.length==3) value[0] = a3[2]; // single value but as an array(1) so that we know how to handle it later
else value = Array.slice(a3,2,a3.length); //array of values

if (returntype=="boolAsInt" ) 
	{test=(value[0]=="true");  return test;}// bool as int from 1 element array
if (returntype=="int" ) return parseInt(value[0]); // int from 1 element array
if (returntype=="float" ) return parseFloat(value[0]); // float from 1 element array
if (returntype=="string" ) return value[0]); // string from 1 element array
if (returntype=="value(s)" ||returntype=="values" || returntype=="value" || returntype=="stringarray") return value; // always an array
FatalError("key *" + key + "* not found in settings file; returntype was " +returntype);
}
function  getDateStamp()
{
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
//year0= year;month0=month; dayOfMonth0=dayOfMonth;hour0=hour; minute0=minute;second0= second;
	//return  toString(year0) + "-" + toString(month0) + "-" + toString(dayOfMonth0) + "-" + toString(hour0) + "-" +toString(minute0) + "-" +toString(second0);
	return  toString(year) + "-" + toString(month) + "-" + toString(dayOfMonth) + "-" + toString(hour) + "-" +toString(minute) + "-" +toString(second);
}


function  DateStampstring()// this is for reports, not suitable for extracting numbers
{
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
year0= year;month0=month+1; dayOfMonth0=dayOfMonth;hour0=hour; minute0=minute;second0= second;
return  toString(year0) + "-" + toString(IJ.pad(month+1, 3-lengthOf(toString(month+1)))) + "-" + toString(dayOfMonth0) + "_" + toString(hour0) + "h" +toString(minute0) + "m" +toString(second0)+"s";
}



function GetDyesUsed(dyetype_kernels, path1)
{
	Probes= newArray();//(7);
	dyetypes = newArray(dyetype_kernels.length);
	probe=0;
	list = getFileList(path1);
	if(Verbosity>3) print("seaching path " + path1 + " for .drt dye files");
	if(Verbosity>3) Array.print(list);
	for (i=0; i<list.length; i++)
		{
		if (endsWith(list[i], ".drt"))
			{
	 		f= File.openAsString(path1+list[i]);
	 		lines=split(f, "\n");
	 		if(Verbosity>1) Array.print(lines);
	 		numprobes =0;
	 		for (j=0; j<lines.length; j++)
				{
					if(lines[j]=="[General]")
					{
					index=indexOf(lines[j+3], "Probes=");
					numprobes= substring(lines[j+3], index+7, lengthOf(lines[j+3]));
					}
				for (k=1; k<numprobes+1; k++)
				{	
	  			if (lines[j]== "[Probe"+k+"]") 
	  				{
	  				index=indexOf(lines[j+1], "Name=");
	  				probename=substring(lines[j+1], index+5, lengthOf(lines[j+1]));
	  				if(Verbosity>1) print("in", list[i], "found", index+1, probename); //index is the line showing "Probes=" starting at 0
	  				Probes= Array.concat(Probes,newArray(probename));
	  				probe++;
	  				}
				}  				
				}
	  			//File.close(f);
			}
		}
	
		print("Found the following dyes in experiment " + path1);
		Array.print(Probes);
		if(Verbosity>1) Array.print(dyetype_kernels);
	//here takes the dyetypes array and fills it out with the actual names used in the present experiment. This means if we used different exposure times, the macro can still figure it out
	foundchannels=0;
	for (i= 0; i<Probes.length; i++)
	{
		for (j= 0; j<dyetype_kernels.length; j++)
		{
			
		if(startsWith(Probes[i], dyetype_kernels[j]))
			{
			dyetypes[j]= Probes[i];
			if(Verbosity>1) print("found ", dyetypes[j],  Probes[i]);
			foundchannels++;}
			}
		}
	
	if (foundchannels != dyetype_kernels.length)
		{
			if(Verbosity>1) print("foundchannels, dyetype_kernels.length are", foundchannels, dyetype_kernels.length);
			message= "Dye kernels are:"; for (i=0;i<dyetype_kernels.length; i++) message=message+" *" + dyetype_kernels[i] + "*";
			print("Could not find all channels. "+message+"Will try next experiment");
			dyetypes=newArray(0);
		}
	 
	 return dyetypes; // dyetype array for current experiment
}



function getWellList(L_wellpath)
{
	list = getFileList(L_wellpath);
	
	//print(String.join(list, "\n"));
	wells = newArray(); 
	well=0;
	for (i=0; i<list.length; i++)
	{
	 if (endsWith(list[i], "/") && (startsWith(list[i], "Well ")))
	 {
	  	wells= Array.concat(wells,newArray(substring(list[i], 5, lengthOf(list[i])-1)));
	 }
	 	//well[wells] = substring(list[i], 5, lengthOf(list[i])-1);
	} 	
	//
	print(wells.length + " wells");
	Array.print(wells); print("");
		return wells;
}
 		


function FillWellArray(L_FirstWell, L_LastWell)
{
	Plate=newArray("96", "384"); 
	CurrentPlate=Plate[lengthOf(L_FirstWell)-3]; //4 chars means 384 else 96
	columnF=substring(L_FirstWell, 1,lengthOf(L_FirstWell));
	columnL=substring(L_LastWell, 1,lengthOf(L_LastWell));
	rowF=charCodeAt(L_FirstWell, 0);// (string, index)substring(FirstWell, 0,1);
	rowL=charCodeAt(L_LastWell, 0);// =substring(LastWell, 0,1);
	if(columnF!=columnL)
		{
		temparray=newArray(2);
		temparray[0]=columnF;
		temparray[1]=columnL; //Array.print(a);
		columns=Array.resample(temparray, columnL-columnF +1);// - Returns an array which is linearly resampled to a different length. 	Array.print(b);
		}
		else 
		{columns = newArray(1); columns[0] = columnF;}
		for (column = 0; column < lengthOf(columns); column++)
			{
			columnstring = ""+columns[column];
			for(i=0; i<lengthOf(CurrentPlate)-1; i++) {if(lengthOf(columnstring) < lengthOf(CurrentPlate)) columnstring="0"+columnstring;}
			columns[column]= columnstring;
			}
	 //Array.print(columns);
	if(rowF!=rowL)
		{
		a=newArray(2);
		a[0]=rowF;
		a[1]=rowL; //Array.print(a);
		rows=Array.resample(a, rowL-rowF +1);// - Returns an array which is linearly resampled to a different length. 	Array.print(b);
		}
		else 
		{rows = newArray(1); rows[0] = rowF;}
	
	wellarray=newArray;
	//wellarray=newArray(columns.length * rows.length);
	for (row = 0; row < lengthOf(rows); row++)
		{
		rowchar= fromCharCode(rows[row]);
		temp=Array.copy(columns);
		for (column = 0; column < lengthOf(columns); column++)
			{
			temp[column]= rowchar +  temp[column];
			}
		wellarray=Array.concat(wellarray, temp);
		}
	Array.print(wellarray);
	
	
	return wellarray;
}
 


//Below are the main functions used above



function AnalyseCurrentRun(experimentpath, L_CurrentRunDateStamp, L_ParameterSettings)
{
	// now L_ParameterSettings is passed, start to use this to access and pass on needed parameters
	CalciumChannel=returnsetting(settinglines, "CalciumChannel", "int");	
	
	//update dye anmes for present experiment if desired
	
	if (!ChannelNames_explicit)	ImageKernels = GetDyesUsed(ImageKernelhints, experimentpath);
	Array.print(ImageKernels);
	WellList=getWellList(experimentpath);//get well list automatically
	if (lengthOf(WellList) ==0) 
		{
		print("no wells in " +experimentpath);
		}
	else
		{
		plates = newArray(96, 384);
		PlateType = plates[lengthOf(WellList[0])-3]; //not really used or reported, but for consistency - currently still used for window reporting -> eliminate
		if(ConstrainWells) //override autowell list but still use it to format names correctly 96 v 384
			{
			if(Verbosity >1)  print("user-defined well constraint");	
			FirstWell = ConstrainedWells[0] + IJ.pad(ConstrainedWells[2], lengthOf(WellList[0])-1);
			LastWell  = ConstrainedWells[1] + IJ.pad(ConstrainedWells[3], lengthOf(WellList[0])-1);
			WellList=FillWellArray(FirstWell, LastWell);
			if(Verbosity >1)  Array.print(WellList);	
			}
		
	
		if((ImageKernels.length !=0) &&(lengthOf(WellList) !=0 )) //we have image names and wells, can proceed
			{	
			
			//here's the place to implement if we want to set a limit on the number of timepoints
			//print("loop through windows");
			if (WindowTimecourse==false)//  if we don't want windows then this ensures there'll be only one calculation cycle
				{TimeWindowLast = TimeWindowFirst+1; TimeWindowStep=TimeWindowLast-TimeWindowFirst+1;}

			//one report per output folder for the whole run! for all windows if any
			processreportstarted=false; segmentationreportstarted=false; collectdatareportstarted=false; 
			 // to keep track of whether to add to or start a new report
			// these are updated outside functions
	
			if(Preprocess) ProcessReportFile=experimentpath+ File.separator +AlignmentFolder+"ImageProcessingReport"+L_CurrentRunDateStamp+".txt";  
			if(Segment) SegmentReportFile=experimentpath + SegmentationFolder+File.separator+"Segmentation"+L_CurrentRunDateStamp+".txt";   
			if (CollectData) CollectDataReportFile= experimentpath+ OutputFolderKernel+ThresholdCode + File.separator+"DataCollection"+L_CurrentRunDateStamp+".txt";   
	
			for (Window=TimeWindowFirst; Window<TimeWindowLast+1; Window +=TimeWindowStep)
				{	//FirstTimepoint = TimeWindows[Window]; LastTimepoint = TimeWindows[Window+1];
				FirstTimepoint = Window; //no need for LastTimepoint, and can still offset start and use rest if choose to
				
			
			if (WindowTimecourse == true)
					{
					NumberTimepoints = TimeWindowStep;
					Timewindow = "Window_"+FirstTimepoint+"to"+FirstTimepoint+NumberTimepoints-1;
					MergedDataPath = experimentpath   +AlignmentFolder+ "Window_"+FirstTimepoint+"to"+FirstTimepoint+NumberTimepoints-1 + File.separator;	
					}
				else
					{
					NumberTimepoints = 0; Timewindow = ""; // opportunity to limit the number of timepoints without using windows and subdirs here
					MergedDataPath = experimentpath+AlignmentFolder;//+ File.separator;
					}
				if((Preprocess)|(Segment)|(CollectData))
					{
					
					//Check metadata - only once for all wells; // To modify - if data does not exist, use defaults posted  one directory up -> need to trim experimentpath back to last "//"
					ImageDimensionsFromMetaData = newArray(); ImageDimensionsFromMetaData = getMetaData(experimentpath); //check here ImageDimensions for error value  e.g. -1 and try another path and only then get defaults: getMetaData("default");
					MaxNumberOfROIToDetect= MaxROIsPerField*ImageDimensionsFromMetaData[1]* ImageDimensionsFromMetaData[2];
					Array.print(ImageDimensionsFromMetaData);
					
					//loop through wells
					for (wellID =0; wellID <lengthOf(WellList); wellID++) 
						{
						CurrentWell = WellList[wellID];
						rowcode = charCodeAt(CurrentWell,0); columncode = substring(CurrentWell,1);
						//for (rowcode=charCodeAt(FirstRow, 0); rowcode<charCodeAt(LastRow, 0)+1;rowcode++) 				//{				//Row = fromCharCode(rowcode); 
						if (GroupType == "Row") {GroupNumber = 2 - ((rowcode+1) % GroupCount);} // that's 2 or 1 no 0 //Note that we assume here that B02 is group 1 so A01 would be group2
						else {GroupNumber = 1;} 
						//for (columncode=FirstColumn; columncode<LastColumn+1;columncode++) //+1 because ends one col early otherwise				//	{
						if (GroupType == "Column") {GroupNumber = 2- ((columncode+1) % GroupCount);} else {GroupNumber = 1;}// that's 2 or 1 no //Note that we assume here that B02 is group 1 so A01 would be group2 //Note 2 no else, it is set by column or at one already, dont change it!
						//CurrentWell = formatWellCode(Row, columncode, PlateType);	 //now simplified
						well_aborted= false; //starting new well now, nothing failed yet
						wellpath=experimentpath+"Well "+CurrentWell + File.separator; //example=path + "CFP - n000001.tif"; //not necessary?
						if (Verbosity >1) print("Group " + GroupNumber);	

						//have to determine the signal names depending on the groups //need signals = newArray("copy", "ERK", "Ca");//
						//use signals according to group associated with this well
						firstchannel = Channels * (GroupNumber -1);	lastchannel = Channels * (GroupNumber);
						SignalNamesRGB = Array.slice(SignalNamesRGBgroups, firstchannel, lastchannel); // 3,6 or 0, 3
						// so Channels = SignalNamesRBG.length, can use this in functions
						// Pass Channels, ImageKernels and SignalNamesRGBgroups as well as passed parameter Group
						currentImageKernels = Array.slice(ImageKernels, firstchannel, lastchannel); // 3,6 or 0, 3
						
//DEBUG
					setBatchMode(true);
						if (Preprocess)
							{
							print("\\Update:" + "Seeking " + Timewindow + " well " + CurrentWell + " at "+ experimentpath); if(Verbosity>1) print("");
							if(!File.exists(wellpath))//check Well exists [but we do not really need that for Segment and the other 
								{
								if (Verbosity >0) {print("\\Update:" + "The well "+ CurrentWell + " does not exist at path " + wellpath+ ". If that does not seem right, check the path. Will now try to find the next well."); print("");}}
							else
								{
								AlignFlags = newArray(AlignTimepoints,AlignWithNanoJ);//max 20 parameters can be passed, so I have to combine some!
								well_aborted=!ProcessRun(experimentpath, CurrentWell, ImageDimensionsFromMetaData, AlignFlags, AlignmentFolder, GeometricCorrection, GeometricDistortionCorrectionFactor, GroupNumber, RB, tmppath,NumberTimepoints, FirstTimepoint, ImageTimeInterval, InterburstAlignmentRef, CaFramespreAdd, CaFramespostAdd,  AlignerChannelNumber, Segment, processreportstarted, ProcessReportFile); 
								processreportstarted=true ;//even if aborted
								} //signal names etc determined by group number because it can vary; Segment flags to keep images open
							}

								
						if(Segment && !well_aborted)
							{
							print(printformatter + "Seeking " +  Timewindow + " merged image "+ CurrentWell + " at "+ MergedDataPath); if(Verbosity>1) print("");
							if(File.exists(MergedDataPath +"Merged"+CurrentWell+".tif"))  //does not need wellpaths, the processed tiffs are sufficient
								{				
//DEBUG								//hard coded here
								cytoChannel=2; //EDIT - need to free this up for user access
								SegmentImages(SegmentationChannel, cytoChannel,CalciumChannel, UseExistingROIs, UseStarDist, CurrentWell, AlignmentFolder,
												experimentpath, SegmentationFolder, SegmentationSettings, ErodeCycles, 
												BandWidth, NoOverlapBandAlgorithm, GroupNumber, SignalNamesRGB, 
												NumberTimepoints, FirstTimepoint, MaxNumberOfROIToDetect, 
												segmentationreportstarted, SegmentReportFile); 
								segmentationreportstarted=true ;
								}
							else
								{print("Did not find image stack "+(MergedDataPath +AlignmentFolder+ "Merged"+CurrentWell+".tif") + ". Trying next well.");}
							}
						
						// last resort to clean up when using Fast4DReg_-2.0.0-jar-with-dependencies.jar
						//list = getList("image.titles"); if (list.length != 0) {close();} //  getting leftover images in batch mode if use Fast4DReg_-2.0.0-jar-with-dependencies.jar even if they are all close without batch mode//
						
						if (CollectData && !well_aborted) 
							{
							print(printformatter + "Seeking " + Timewindow + " data for " + CurrentWell + " at "+ experimentpath+  SegmentationFolder+ File.separator+Timewindow); if(Verbosity>1) print("");
							well_aborted=!ThresholdandCalcSignals(SegmentationChannel, CalciumChannel, RatioPairs, experimentpath, 
								SegmentationFolder, OutputFolderKernel, CurrentWell, GroupNumber, SignalNamesRGB, Timewindow, 
								BaselineReads, collectdatareportstarted, CollectDataReportFile, ThresholdArray, ThresholdCode);						
							collectdatareportstarted=true ;
							}	
							setBatchMode(false);	
						}		
					}
					
					//outside well and therefore group loop, collate existing data across experiment, need to generate SignalNamesRGB as may not exist [test this with groups, shouldn't the whole all-groups array be used?]
					//from now on always collect the calcium spike data
					
					if (CollateData && (CalciumChannel !=-1)) AnalyseSpikes(Channels, CalciumChannel, 
					SignalNamesRGBgroups,GroupCount, experimentpath,  OutputFolderKernel,  WellList, 
					Timewindow, ThresholdCode);
					
					
					if (CollateData) SaveAverageTraces(parameters_collected_per_channel, Channels, CalciumChannel, SegmentationChannel, SignalNamesRGBgroups, RatioPairs, GroupCount, experimentpath, OutputFolderKernel,  WellList, Timewindow, ThresholdCode); //this one combines wells and time-windows and has to have its own well-loop within the function
					
				}
			
			
			
			
			
			
			if (MergeWindowFiles && WindowTimecourse) collectWindowData(parameters_collected_per_channel, Channels, CalciumChannel, SegmentationChannel, SignalNamesRGBgroups, GroupCount, RatioPairs, TimeWindowFirst, TimeWindowLast,TimeWindowStep, experimentpath, OutputFolderKernel, ThresholdCode); //both must be true
			
			
			}
		}//next experiment
	//It's done - clean up
	
	if (isOpen("Results")) { selectWindow("Results"); run("Close");}
} 



function formatWellCode(L_row, L_columncode, L_plate)
	{
	Column =L_columncode; if (L_columncode<10) {Column = "0" + L_columncode;} 
	if (L_plate==96)
		{L_currentWell=L_row + Column;}
	else if (L_plate==384)
		{
		L_currentWell=L_row +"0" + Column;
		}
	else FatalError("Invalid Plate Type, only 96 and 384 are valid values");
			
	return	L_currentWell;
}




function ProcessRun(experimentpath, Well, ImageDimensions, L_AlignFlags, L_AlignmentFolder, 
 L_GeometricCorrection, L_GeometricDistortionCorrectionFactor, Group, RB, L_tmppath,
 NumT, FirstT, TimeInterval, L_InterburstAlignmentRef, L_CaFramespreAdd, L_CaFramespostAdd, 
 L_AlignerChannelNumber, segment, reportstarted, L_ProcessReportFile)//L_SignalNamesRGB determined from group; segment flag tells if files should be left open
{
	print(printformatter+ "Processing well " + Well + " at "+ experimentpath);  //setBatchMode(true); should be done around both process and segment so that images are passed silently
	
	//define contents of passed arrays
	L_AlignTimepoints=L_AlignFlags[0];L_AlignWithNanoJ=L_AlignFlags[1];
	xFields=ImageDimensions[1]; yFields=ImageDimensions[2]; TilePixelsX=ImageDimensions[3]; TilePixelsY=ImageDimensions[4];PixelSizePostBin= ImageDimensions[5]; //[0] is left with a zero as it was never used.
	
	
	
	//set up the subdirectories for the output files
	if(L_AlignmentFolder!="") 
		{	
		OutputDir = experimentpath + File.separator +L_AlignmentFolder;
		if(!File.exists(OutputDir)) File.makeDirectory(OutputDir);
		} // if L_AlignmentFolder=="" we dump the data in the existing folder, does that ever happen??
	
	if( NumT!=0) L_WindowTimecourse=true;
	else L_WindowTimecourse=false;
	
	if(L_WindowTimecourse) 
		{
		L_Timewindow = "Window_"+FirstT+"to"+FirstT+NumT-1+ File.separator;
		CurrentTimewindowDir = OutputDir+ L_Timewindow; 
		}
		else 
		{
			L_Timewindow="";
			CurrentTimewindowDir = OutputDir; 
		}
	
	if (!File.exists(CurrentTimewindowDir)) File.makeDirectory(CurrentTimewindowDir);
		
	// below needs currentImageKernels, L_SignalNamesRGB
	L_SignalNamesRGB=SignalNamesRGB;// should have been passed, need to fix this, already 20 parameters passed!
	
	//Generate Report
	//reportfile=experimentpath+ File.separator +L_AlignmentFolder+"ImageProcessingReport"+DateStampstring()+".txt";  //Merged files will overwrite so there's no point making a unique ID
	if (!reportstarted)  File.saveString("Processing Data - starting/version "+VersionNumber+ " using IJ version " + IJVersionRunning + "\r\n"+ "\r\n",L_ProcessReportFile);
	else  File.append("\r\n",L_ProcessReportFile);
	File.append("Time Window="+L_Timewindow+ "\r\n", L_ProcessReportFile);
	File.append("Well="+Well+ "\r\n", L_ProcessReportFile);
	File.append("experimentpath="+experimentpath+ "\r\n", L_ProcessReportFile);
	File.append("Alignment Data="+L_AlignTimepoints+ "\r\n", L_ProcessReportFile);
	File.append("Alignment Folder="+L_AlignmentFolder+ "\r\n", L_ProcessReportFile);
	File.append("Use NanoJ for alignment="+L_AlignWithNanoJ+ "\r\n", L_ProcessReportFile);
	File.append("Group="+Group+ "\r\n", L_ProcessReportFile);
	File.append("Rolling ball value for background subtraction="+RB+ "\r\n", L_ProcessReportFile);
	File.append("temporary path="+L_tmppath+ "\r\n", L_ProcessReportFile);
	File.append("Analysing by time window?="+WindowTimecourse+ "\r\n", L_ProcessReportFile);
	File.append("Number of Timepoints in current window="+NumT+ "\r\n", L_ProcessReportFile);
	File.append("First Timepoint in current window="+FirstT+ "\r\n", L_ProcessReportFile);
	File.append("Channel used for Alignment="+L_AlignerChannelNumber+ "\r\n", L_ProcessReportFile);
	File.append("Ratio of Ca images to  other images CondenseFactor= "+CondenseFactor+ " to  1 \r\n", L_ProcessReportFile);
	File.append("InterburstAlignmentRef="+L_InterburstAlignmentRef+ "\r\n", L_ProcessReportFile);
	File.append("CaFramespreAdd="+L_CaFramespreAdd+ "\r\n", L_ProcessReportFile);
	File.append("CaFramespostAdd="+L_CaFramespostAdd+ "\r\n", L_ProcessReportFile);
	File.append("segment right after?="+segment+ "\r\n", L_ProcessReportFile);
	Channelkerneltext = ""; for(i=0; i<Channels; i++) {Channelkerneltext  = Channelkerneltext  + toString(currentImageKernels[i]) + ", ";}
	Channelnametext= ""; for(i=0; i<Channels; i++) {Channelnametext  = Channelnametext  + toString(L_SignalNamesRGB[i]) + ", ";}
	File.append("Channels included by Dye names in raw data = "+Channelkerneltext+ "\r\n", L_ProcessReportFile);
	File.append("Corresponding names used for channels  = "+Channelnametext+ "\r\n", L_ProcessReportFile);
	GeoCorrString = ""; for(i=0; i<Channels; i++) {GeoCorrString = GeoCorrString +toString(L_GeometricCorrection[i]) + ", ";}
	File.append("GeometricDistortionCorrection of Channels (0 = no, 1 = yes) = "+GeoCorrString+ "\r\n", L_ProcessReportFile);
	File.append("GeometricDistortionCorrectionFactor (for R-iR images)="+L_GeometricDistortionCorrectionFactor+ "\r\n", L_ProcessReportFile);
	//end report
	
	
	
	
	
	
	
	
	Wellpath=experimentpath+"Well "+Well+"\\";
	
	
	//work-around function for imagej intolerance in run("Image Sequence...) when 16bit bmp created earlier than the tiffs (even if we only ask for tiffs!)
	//ChangeFileExtensions(Wellpath, "bmp", "bmp16"); // recover them later 
	//targetfiles=L_Wellpath + "*.bmp"; targetfiles=replace(targetfiles, "/",File.separator); exec("cmd", "/c", "rename", targetfiles, "*.bmp16");
	//ChangeFileExtensions(Wellpath, "bmp", "bmp16"); // recover them later 
	//targetfiles=L_Wellpath + "*.bmp"; targetfiles=replace(targetfiles, "/",File.separator); exec("cmd", "/c", "rename", targetfiles, "*.bmp16");
	//not good enough any more
	
	//BuryFileWithExtensions(Wellpath, "bmp"); // no need to recover them later 
	
	
	mergestring ="";
	if (Verbosity>1) print(printformatter+ "Loading channels for  well " + Well + " at "+ experimentpath); 
	//perform sub-alignment within measurement bursts, geometric corrections, and define mergestring
		for(i=0; i<Channels; i++)
			{
			if(i == CalciumChannel-1) //SignalNamesRGB[i] == "Ca")  now a channel can be called Ca without conflict over CalciumChannel =-1// comes back with a condensed version and the full as "Ca-stack"
				getCaSubalignCondense(currentImageKernels[i], L_SignalNamesRGB[i], Wellpath, RB, NumT*CondenseFactor, (FirstT-1)*CondenseFactor+1, "Ca-stack", CondenseFactor, L_InterburstAlignmentRef, L_CaFramespreAdd, L_CaFramespostAdd, L_AlignWithNanoJ);
			else
				getchannelrange(currentImageKernels[i], L_SignalNamesRGB[i], Wellpath, RB, NumT, FirstT); // usually ERKktr 
			if(L_GeometricCorrection[i]==1)
				CorrectGeometricDistortion(L_SignalNamesRGB[i], L_GeometricDistortionCorrectionFactor);
			if(Channels >7)
				mergestring = mergestring + "image" + i+1 + "=" + L_SignalNamesRGB[i] +  " "; // using stack
			else
				mergestring = mergestring + "c" + colour[i+1] + "=" + L_SignalNamesRGB[i] +  " ";
			}
		//this was no longer sufficient
		//ChangeFileExtensions(Wellpath, "bmp16", "bmp"); // recover the renamed bmp files	
	//	setBatchMode("exit and display"); stop; 
		
	// Note: data validated below but calcium gets "sub"-aligned above with function "getCaSubalignCondense()"
	//, why align a large dataset if it is not valid -> the  Ca alignment is after validation?	
	// the subalign tries to correct for the pre/post pipetting disturbances before creating the condensed Ca stack... this is why it is done before the validation that uses the condensed stack
			
	if (Verbosity>1) print(printformatter+ "Validating channels for  well " + Well + " at "+ experimentpath); 		
	
		if(Channels!=1) 
		{
			validity_check = validate_imagestack_compatibility(L_SignalNamesRGB); // the longer Ca_stack has a different name and is not considered here, only the compressed one is evaluated
			
			if(!validity_check) 
				{
				errortext="WELL ERROR: unmatched image numbers in current well";
				File.append(errortext+"\r\n", L_ProcessReportFile);
				print(errortext);
				return false; //validity checker closes images
				}
			if(Channels <7)
				{
				run("Merge Channels...", mergestring +" create");  //run("Merge Channels...", "c1="+L_SignalNamesRGB[0]+" c2="+L_SignalNamesRGB[1]+" c3="+L_SignalNamesRGB[2]+" create"); 
				getDimensions(w, h, mergechannels, slices, frames); 
				if(frames==1)
					{// the output is "composite" not merged when there's only one slice, and the Ca stack was preselected so I had to select "Composite" but only if it is actually called that!
					selectWindow("Composite"); 
					rename("Merged"); 
					}
				}
			else	
				{
				run("Concatenate...", "keep open "+ mergestring); //this concatenates channels as additional timepoints by default
				getDimensions(w, h, mergechannels, slices, frames); 
				run("Stack to Hyperstack...", "order=xyczt(default) channels="+Channels+" slices="+slices+" frames="+frames/Channels+" display=Color");
				rename("Merged");//Composite"); //for compatibility
				}
		}	
		else //Merge channels command is just skipped if there is only one file and it ends up with the wrong name, crashing the macro
			rename("Merged");
		
		if (Verbosity>1 && L_AlignTimepoints) print(printformatter+ "Aligning channels for  well " + Well + " at "+ experimentpath); 	
		getDimensions(w, h, mergechannels, slices, frames);
		//calibrate properties to ensure segmentation band later is going to be 1 pixel not 1 inch wide!
		run("Properties...", "channels="+mergechannels+ " slices="+ slices + " frames="+frames+" unit=um pixel_width="+PixelSizePostBin +" pixel_height="+PixelSizePostBin +" voxel_depth=1 frame=["+TimeInterval+"]");
	
		if (!(frames==1) && L_AlignTimepoints)//only do something if there's only 1 timepoint and request to align
			{
			AlignToSlice = "first"; // can set to last if initial images are dimmer
			Align4DImage2("Merged", L_tmppath, "C"+AlignerChannelNumber, AlignToSlice, L_AlignWithNanoJ);	//Apply Align4Dimage function
			selectWindow("Merged"); // keeps losing focus!
			}
	
	saveAs("Tiff", CurrentTimewindowDir + "\\Merged"+Well+".tif"); // 
	if (SaveMergedAsAVI) run("AVI... ", "compression=JPEG frame=7 save="+CurrentTimewindowDir + "\\Merged"+Well+".avi"); // compressed avi for convenience; on Win10 dont need to do RGB convert etc
	
	
	if (Verbosity>1) print(printformatter+ "Collecting fieldwide values for  well " + Well + " at "+ experimentpath); 	
	
	//Record field-wide average intensity 
	// start the file, delete old file if this is the first well and there's one there, so that the data correspoding to the latest processed images is saved
	// *Modify* behaviour version v5d29h- : include timestamp so that previous files are not automatically deleted, 
	// because occasionally the process step is run more than once e.g. adjusting parameters, combining data 
	if (!reportstarted) // this is by time window, exactly what we need here
		{

		for (channel = 0; channel<mergechannels; channel++)
			{
			file= CurrentTimewindowDir + "\\FieldAverage_"+L_SignalNamesRGB[channel]+"_" + CurrentRunDateStamp+".csv";
			if (File.exists(file)) a=File.delete(file);
			Colnames = "Well/timepoint:";for (timepoint = 0; timepoint < frames;timepoint++) {Colnames=Colnames +"," + timepoint;}
			File.append(Colnames, file);
			}
		}
		
	
	// reorganise and append data to the (new) file - now it is going to be one line per well, so timepoint, if any, is going to be by column
	for (channel = 0; channel<mergechannels; channel++)
		{
		csvaveragebytime=Well; //start the string to save to file
		Stack.setChannel(channel+1); //confusingly, setChannel and setFrame start at 1 not 0, and dont give an error if set to 0
		for (frame=0; frame< frames; frame++) // Gatherhing UNCALIBRATED PIXEL values
			{Stack.setFrame(frame+1);	 //confusingly, setChannel and setFrame start at 1 not 0, and dont give an error if set to 0
			ValueFromCurrentFrame=getValue("Mean raw");
			csvaveragebytime= csvaveragebytime + "," + ValueFromCurrentFrame;
			}
		file=CurrentTimewindowDir + "\\FieldAverage_"+L_SignalNamesRGB[channel]+"_" + CurrentRunDateStamp+".csv";
		File.append(csvaveragebytime, file);
		}
	
	//the following is to extract the max Ca projection from the concise Ca tc as an alignment template, align  the full tc to this (did it work?), and save the aligned fullCa tc
		if((CalciumChannel!=-1)&& (CondenseFactor!=1)) //if((SignalNamesRGB[2]!="None")*(CondenseFactor!=1))
			{
			if (L_AlignTimepoints)
				{	
				selectWindow("Merged"+Well+".tif");
				AlignerForFastCa =CalciumChannel;//this has to be the condensed Ca channel, not one of the others that could be used for the Merged staock as AlignerChannelNumber
				run("Duplicate...", "duplicate channels="+AlignerForFastCa); rename("temp"); 
				selectWindow("temp");  CondensedSlices= nSlices; 
				if (CondensedSlices!=1) //catch error when there happens to be only a single plane in the experiment 
					run("Z Project...", "projection=[Max Intensity]"); 
				else 
					{run("Select All"); run("Duplicate...", "duplicate"); }
				
				rename("Aligner"); selectWindow("temp");close(); 
				if (Verbosity >1) print(CondensedSlices*CondenseFactor+ " slices in Ca stack"); //don't use nSlices this changes depending on the last image focus		
				if (!L_AlignWithNanoJ) GenerateZstackFromSingleImage("Aligner", CondensedSlices*CondenseFactor); // that's the number of slices in Ca-stack and it should be the same in the final Aligner too. Do not use nSlices it is a current image parameter	//run("Slice Remover", "first=1 last=22 increment=1");
				
				//Use AlignStacks wrapper
					//run("MultiStackReg", "stack_1=Aligner action_1=[Use as Reference] file_1=[] stack_2=Ca-stack action_2=[Align to First Stack] file_2=[] transformation=Translation");
					// THIS SLOWS EVERYTHING DOWN because of the number of calcium timepoints ! Fiji has a new alternative to MultistackReg - compare processing times
					// note mulitstack reg uses turboreg that saves temp files so multiple instances can clash! http://bigwww.epfl.ch/thevenaz/stackreg/
				
				temp=AlignStacks(L_AlignWithNanoJ, "Aligner", "", "Ca-stack", "[Translation]", "", ""); //"" means don't save
				if (L_AlignWithNanoJ) a=File.delete(temp); //clean up the temp file, cannot do this in the wrapper because don't know if it will be reused		
				
				selectWindow("Aligner"); close();
				
				}
		selectWindow("Ca-stack");saveAs("Tiff", CurrentTimewindowDir + "\\FastCa"+Well+".tif");
		if (!segment) close(); //leave open for the segmentation function if it was selected
		}
	else //no compression, no additional Ca data to save
		{if(CalciumChannel!=-1) {selectWindow("Ca-stack");close();}}
			
	
	//leave open for the segmentation function if it was selected
	if (!segment) fullyClose("Merged"+Well+".tif"); // close does not work in batch mode today 2022-10-31, only if I used F4DR jar -  I have to close again at the after BatchMode(false) or twice here!
	
	
	
	print(printformatter +"Processed Well " + CurrentWell + " in " + experimentpath);
	//setBatchMode(false);  // should be done around both process and segment so that images are passed silently, or this will cause images to appear
	
	return true;
}





function CloseSelectWindows(WindowsToClose) 
{
	for (i=0; i< WindowsToClose.length; i++) 
		{
		selectWindow(WindowsToClose[i]); 
		close();
		}
}


function fullyClose(ImageTitle) //combining use of Fast4DReg_-2.0.0-jar-with-dependencies.jar with this code *in BatchMode* can block selectedWindow close()!
{
	//version 2, because imageIDs are dynamically reallocated after a close
	attempt= 0;
	for (i=0;i<100;i++)
		{
		list = getList("image.titles"); 
		for (j=0;j<list.length; j++)
		{
		if (list[j]== ImageTitle) //found the target
			{
			if (attempt>0) print("attempt #"+attempt+" to close image"+ImageTitle + " failed. Trying again");
			selectWindow(ImageTitle); close();
			attempt+=1;j=list.length; // exit list search
			}
		if (i > attempt-1) i=100; //if true, a search cycle found no target, it is now gone
		}
		}
}


//******** FUNCTION GetMetaData

function getMetaData(MetaPath)
{
	//>>>>>>>>>Tiling determined from Experiment.exp, no need to enter settings here for field-by-field bsub<<<<<<<<<<
	// - binning may change, though camera may not
	//CameraWidth=1344; CameraHeight= 1024; Bin=2; h=(CameraHeight/Bin); w=(CameraWidth/Bin); 
	// yFields= getHeight()/(CameraHeight/Bin); xFields=getWidth()/(CameraWidth/Bin);
	//note this is in Experiment.exp file
	
	MetadataExpFile = MetaPath + "Experiment.exp";
	print("Metadata File at "  + MetadataExpFile);
	
	Metadata=File.openAsString(MetadataExpFile);
	lines=split(Metadata, "\n"); 
	xFields=""; yFields=""; TilePixelsX="";TilePixelsY=""; ObjName = ""; Binning = 0; PhysicalPixelSize=0;
	
	ObjectiveNext = false;
	for (i=0; i<lines.length; i++)
	{
		arg= split(lines[i], "=");
		if (arg[0]== "TilesX") {xFields= arg[1];}
		if (arg[0]== "TilesY") {yFields = arg[1];}
		if (arg[0]== "TilePixelsX") {TilePixelsX = arg[1];}
		if (arg[0]== "TilePixelsY") {TilePixelsY = arg[1];}
		if (ObjectiveNext == true) 
			{
			if (arg[0] == "Name") 
				{
				ObjName = arg[1]; 
				ObjectiveNext=false;
				}
			}
		if (arg[0] == "[Geometry]") {ObjectiveNext = true;}
		if (arg[0]== "BinX") {Binning = parseFloat(arg[1]);}
		}	
	
	if(xFields == "") 
		{xFields = 2; print("WARNING: failed to read X tiling data from exp file "+MetadataExpFile + "; using default values which may not suit, causing the script to crash.");print("");} 
	if(yFields == "") 
		{yFields = 2; print("WARNING: failed to read Y tiling data from exp file "+MetadataExpFile + "; using default values which may not suit, causing the script to crash.");print("");} 
	
	if(TilePixelsX == "") 
	{TilePixelsX = 672; print("WARNING: failed to read X tile size from exp file "+MetadataExpFile + "; using default values which may not suit, causing the script to crash.");print("");} 
	
	if(TilePixelsY == "") 
		{TilePixelsY = 512; print("WARNING: failed to read Y tile size from exp file "+MetadataExpFile + "; using default values which may not suit, causing the script to crash.");print("");}
		
	if(Binning == 0) {Binning = 2;print("WARNING: failed to read binning from exp file "+MetadataExpFile + "; using default bining value which may not suit, giving an incorrect xy calibration.");}// binning value
	if(ObjName=="") {PhysicalPixelSize = 0.625 ;print("WARNING: failed to read Y tile size from exp file "+MetadataExpFile + "; using default pixel size which may not suit, giving an incorrect xy calibration.");} //default pixel size
	
	if(ObjName!="") 
		{
		Metadata=File.openAsString(MetaPath + ObjName + ".geo");
		lines=split(Metadata, "\n");
		for (i=0; i<lines.length; i++) 	
			{
			arg= split(lines[i], "=");
			if (arg[0]== "Scale")  PhysicalPixelSize = parseFloat(arg[1]);
			}
		}
	
	//use defaults to allow calculations during run when experiment.exp has not yet been written!
	
	
	ImageDimensions  = Array.concat(ImageDimensions , xFields);
	ImageDimensions  = Array.concat(ImageDimensions , yFields);
	ImageDimensions  = Array.concat(ImageDimensions , TilePixelsX);
	ImageDimensions  = Array.concat(ImageDimensions , TilePixelsY);
	ImageDimensions  = Array.concat(ImageDimensions ,Binning* PhysicalPixelSize);
	//note ImageDimensions[0] is 0 and this comes back with 6 elements including #0
	return ImageDimensions;
}


 
function validate_imagestack_compatibility(L_StackNames)
{
	L_Channels = lengthOf(L_StackNames);
	//validate channel equivalency first
	
		w_array = newArray(L_Channels);
		h_array  = newArray(L_Channels);
		channelcount_array  = newArray(L_Channels);
		slices_array  = newArray(L_Channels);
		frames_array  =  newArray(L_Channels);
		valid=true; //default
		for(i=0; i<L_Channels; i++) //get dimensions of each image
			{
			selectWindow(L_StackNames[i]);
			getDimensions(w_array[i], h_array[i], channelcount_array[i], slices_array[i], frames_array[i]); 
			}
		for(i=0; i<L_Channels; i++) //compare each pairwise. Usually correct so have to compare all, no time benefit to abort comparisons on first fail
		{
			if(valid)
			{
			for(j=i+1; j<L_Channels; j++)
				{
				if(w_array[i] != w_array[j]) valid =false;
				if(h_array[i] != h_array[j]) valid =false;
				if(channelcount_array[i] != channelcount_array[j]) valid =false;
				if(slices_array[i] != slices_array[j]) valid =false;
				if(frames_array[i] != frames_array[j]) valid =false;
				}
			}	
		}
		
		if(!valid)
			{
				for(i=0; i<L_Channels; i++) //get dimensions of each image
					{
					selectWindow(SignalNamesRGB[i]);
					close();
					Array.print(w_array);
					Array.print(h_array);
					Array.print(channelcount_array);
					Array.print(slices_array);
					Array.print(frames_array);
					}
				return false; //exit function with abort flag
			}
		else 
			return	true;
}


 

function getchannelrange(channel, name, exampleimage, RBvalue, Num, First)  //example image is provided as Wellpath
{
CurrentBatchMode= is("Batch Mode");
setBatchMode(true);
type = channel+" - n"; //run("Image Sequence...", "open=["+exampleimage+"] number=100 file=["+type+"] sort"); // limit to 100 images in tests

//check there are images there or this will crash
foundimages=0; list = getFileList(exampleimage); for (i=0;i<list.length; i++) if (endsWith(list[i], ".tif")) foundimages++; 
//if (Verbosity>2)
 print(printformatter + "Found "+ foundimages + " tifs");

if (foundimages==0) FatalError("no tifs at path "+ exampleimage); // could allow to continue but this suggests there's a serious error

if(Num==0)
{
	run("Image Sequence...", "open=&exampleimage file=[&type] sort"); //{run("Image Sequence...", "open=["+exampleimage+"] file=["+type+"] sort");}
}
else
{
	run("Image Sequence...", "open=[&exampleimage] number=&Num starting=&First file=[&type] sort"); //{run("Image Sequence...", "open=["+exampleimage+"] number="+Num+" starting="+ First + " file=["+type+"] sort");}
}

	

rename(name);
Processedimage = BsubByField(name, xFields, yFields, TilePixelsX, TilePixelsY, RBvalue); //rename(name); // because the function renames as Bsub! //assuming 10x 
run("Properties...", "channels=1 slices=1 frames="+nSlices+"  unit=um pixel_width="+PixelSizePostBin +" pixel_height="+PixelSizePostBin +" voxel_depth=1 frame=[1 min]");

setBatchMode(CurrentBatchMode);
}

function getCaSubalignCondense(L_BlueCodedKernel, L_SignalNamesRGB_blue, L_Wellpath, L_RB, L_numframes, L_firstframe, L_StackName, L_CondenseFactor, L_SplitAlignment, L_FramesPre, L_FramesPost, LL_AlignWithNanoJ) //NumT*CondenseFactor, (FirstT-1)*CondenseFactor+1, "Ca-stack")
{
// single Ca frames can be noisy. It would be easier just to align all images, but should do some time-averaging first. This is complicated by additions during  50 frame runs
run("Conversions...", " ");//turn off auto-scaling on bit-depth change: here is converted to 32bit and back to 16bit to combine pre and post proportionately
getchannelrange(L_BlueCodedKernel, L_SignalNamesRGB_blue, L_Wellpath, L_RB, L_numframes, L_firstframe); // usually calcium"
run("Duplicate...", "duplicate"); rename(L_StackName); //substitute for more compact code that for some reason  crashes out of the function before condensing: run("Duplicate...", "title="+L_StackName);
condensecalcium  = nSlices/L_CondenseFactor;
//print("generating # of frames: " + condensecalcium);

if(L_SplitAlignment=="no")
	{	
	selectWindow(L_SignalNamesRGB_blue);  run("Size...", "width=" + getWidth() + " height=" + getHeight() + " depth="+condensecalcium +" constrain average interpolation=Bilinear");
	}
	else
	{//iterate through all frames by CondenseFactor grouping, aligning according to L_SplitAlignment. Will still proceed with inter-CFgroup alignment later
	if (L_FramesPre+ L_FramesPost>L_CondenseFactor) FatalError("You have selected a split alignment with more frames than exist. Check that CaFramespreAdd + CaFramespostAdd = CondenseFactor = 50 in your settings."); 
	ProgressString="Sub-Aligning";
	if (Verbosity >1) print(""); //generate line indicating progress	
	for(framebatch=0;framebatch<condensecalcium;framebatch++)
		{
		if (Verbosity >1) print("\\Update:"+ProgressString);
		ProgressString=ProgressString+".";
		firstframePre=framebatch*L_CondenseFactor +1; lastframePre=firstframePre -1 +L_FramesPre;
			selectWindow(L_SignalNamesRGB_blue); run("Duplicate...", "title=Pre duplicate range="+firstframePre+"-"+lastframePre);
			run("Size...", "width=" + getWidth() + " height=" + getHeight() + " depth=1 constrain average interpolation=Bilinear");
		firstframePost=lastframePre+1; lastframePost=firstframePost-1+L_FramesPost;
			selectWindow(L_SignalNamesRGB_blue); run("Duplicate...", "title=Post duplicate range="+firstframePost+"-"+lastframePost);
			run("Size...", "width=" + getWidth() + " height=" + getHeight() + " depth=1 constrain average interpolation=Bilinear");

		//Use AlignStacks wrapper
		if (toLowerCase(L_SplitAlignment)=="post")//Align pre to post
			{
			temp=AlignStacks(LL_AlignWithNanoJ, "Post", "", "Pre", "[Translation]", "", ""); //"" means don't save, [] only needed when spaces included
			//run("MultiStackReg", "stack_1=Post action_1=[Use as Reference] file_1=[] stack_2=Pre action_2=[Align to First Stack] file_2=[] transformation=Translation");
			}
		else if (toLowerCase(L_SplitAlignment)=="pre")//Align post to pre
			{
			temp=AlignStacks(LL_AlignWithNanoJ, "Pre","", "Post", "[Translation]", "", "");  //"" means don't save, [] only needed when spaces included
			//run("MultiStackReg", "stack_1=Pre action_1=[Use as Reference] file_1=[] stack_2=Post action_2=[Align to First Stack] file_2=[] transformation=Translation");
			}
		else FatalError("User parameter input error: Alignment option must be 'pre', 'post' or 'no'"); 
			
			
			
		
		if (LL_AlignWithNanoJ) a=File.delete(temp); //clean up the temp file

		
		//Now combine with bias according to pre-post balance
		selectWindow("Pre");run("32-bit"); run("Multiply...", "value="+(L_FramesPre/L_CondenseFactor));
		selectWindow("Post");run("32-bit"); run("Multiply...", "value="+(L_FramesPost/L_CondenseFactor));
		imageCalculator("Add create 32-bit", "Pre", "Post"); CloseSelectWindows(newArray("Pre", "Post"));		
		selectWindow("Result of Pre"); //print(nSlices, framebatch);
		
		if(framebatch==0) //first condensed frame
			{
			rename("OutputStack");
			}
		else // add this frame to the previous stack
			{
			run("Concatenate...", "  title=[Concatenated Stacks] image1=OutputStack image2=[Result of Pre] image3=[-- None --]");
			selectWindow("Concatenated Stacks");
			rename("OutputStack");
			}
		}
		selectWindow(L_SignalNamesRGB_blue); close();
		selectWindow("OutputStack"); run("16-bit"); rename(L_SignalNamesRGB_blue); //print("frames now = "+nSlices);
	}
	selectWindow(L_SignalNamesRGB_blue);
	run("Properties...", " slices=1 frames="+condensecalcium); // the size command puts t frames to z...
	
}


	
// function bsubbing field by field returning "Bsub" (nothing )
function BsubByField (ImageStackIn, xFields, yFields, TilePixelsX, TilePixelsY, RBvalue) { 



	selectWindow(ImageStackIn);
	for (i=0; i<yFields; i++) {
		for (j=0; j<xFields;j++) {
			selectWindow(ImageStackIn);
			makeRectangle(j*TilePixelsX, i*TilePixelsY,TilePixelsX,TilePixelsY);

			run("Duplicate...", "title="+j+" duplicate"); //duplicate at end duplicates stack
			//rename(j);

			run("Subtract Background...", "rolling=RBvalue sliding stack");

			if (j!=0) {
				run("Combine...", "stack1="+(j-1)+" stack2="+j);
				//run("Stack Combiner", "stack1="+(j-1)+" stack2="+j); not Fiji compatible
				selectWindow("Combined Stacks");
				rename(j);
				}
		}
		selectWindow(j-1); //the final combined horizontal strip
		rename("y"+i);
		if (i!=0) {
			run("Combine...", "stack1=y"+(i-1)+" stack2=y"+i+" combine");
			//run("Stack Combiner", "stack1=y"+(i-1)+" stack2=y"+i+" combine"); not Fiji compatible
			selectWindow("Combined Stacks");
			rename("y"+i);
			}
		}
	selectWindow("y"+i-1); //the final combined horizontal strip
	rename("Bsub");

	selectWindow(ImageStackIn);
	close();
	selectWindow("Bsub");
	rename(ImageStackIn);
	return "Bsub"; 
} 		
	

//Function to correct geometric distortion in the IR image 
//- using objective Olympus 10xNA0.
//- using plate 96w Greier  and 899092 Greiner
function CorrectGeometricDistortion(ImageName, CorrectionFactor) //1.012
{
selectWindow(ImageName); //the iRFP stack
		//expand the iRFP file by 1.2% because there is chromatic aberration
		//run("Duplicate...", "title=copy");
			getDimensions(wd, ht, ch, slices, frames);
			run("Size...", "width="+wd*CorrectionFactor + " height="+ht*CorrectionFactor+" constrain average interpolation=Bilinear");
		run("Canvas Size...", "width="+wd+ " height="+ht+" position=Center-Right");//Center");
		return ;
}



//Wrapper for alternate aligment algorithms
function AlignStacks(UseNanoJ, Ref, transformationfile, Target, method, other_option, LL_AlignToSlice)  //other = " save", " apply"," align", " selfalign"
{
// 4 options
	// 1 align a stack and return a saved transformation reference " save"
	// 2 apply a transformation reference to the stack " apply"
	// 3 align one tc to first (last?)  " align"
	// 4 align two images (maybe multistack reg as good?)	

if (other_option == " save") //the transformation file is going to get created, try up to 100 names to find unique name not existing already
		{
		// in this case transformationfile is just a path because we are going to generate the name here
		selectWindow(Ref); 
		tempkernel=getImageID(); //just a number unique for this instance at least
		transformationfile= L_temporarypath+tempkernel+"transformmatrix.tmp"; // just a name, it does not exist yet and if it does it will change
		for (i=0;i<100;i++) {if(File.exists(transformationfile)) {tempkernel+=1;transformationfile= L_temporarypath+tempkernel+"transformmatrix.tmp";}}
		}

	if (!UseNanoJ) 
		{
		if (LL_AlignToSlice == "last"){selectWindow(Ref); setSlice(nSlices);}
		if (Target=="None") { //other_option tells to  save ref or apply it
			if (other_option == " save") run("MultiStackReg", "stack_1="+Ref+" action_1=Align file_1=["+transformationfile+"] stack_2=None action_2=Ignore file_2=[] transformation="+method+ other_option);
			else if (other_option == " apply") run("MultiStackReg", "stack_1="+Ref+" action_1=[Load Transformation File] file_1=["+transformationfile+"] stack_2=None action_2=Ignore file_2=[] transformation="+method);
			// that one above does not make logical sense it's a target not a ref
			else  run("MultiStackReg", "stack_1="+Ref+" action_1=Align file_1=[] stack_2=None action_2=Ignore file_2=[] transformation="+method);
			} // otherwise just take two images and align
		else  run("MultiStackReg", "stack_1="+Ref+" action_1=[Use as Reference] file_1=[] stack_2="+Target+" action_2=[Align to First Stack] file_2=[] transformation="+method);	
		} else {
				//UseNanoJ - here LL_AlignToSlice is currently ignored - *TO DO*
				if (Target=="None") 
					{
					if (other_option == " apply") 
						{
						selectWindow(Ref); rename("temp"); //NanoJ creates an extra file, kill the old and replace with the new	
						run("F4DR Correct Drift", "choose=["+transformationfile+"]"); //nanoJ drifttable
						rename(Ref);  //print(transformationfile); //debug
						CloseSelectWindows(newArray("temp"));
						}
					else { // if option 4  - can use 1 again if combine images and resplit and rename  
						if (Ref != "" && Target != "None") // align Target stack (1+ images) to Ref (assumes only one for this script)
							{
							run("Concatenate...", "  title=Temporary image1="+Ref+" image2="+Target);
							run("Properties...", "channels=1 slices=1 frames=2");
							}
						// this is  for option 1 or 3 other option = save or "", and 4 after split, if combine at end 
						// 3 is - same as #1 because we always get a ref anyway,just don't use it again (gets deleted)
						//  NanoJ settings, note it has  own ref so generate the ref file inside the function and return it for application	
						time_xy = 1;//disables time averaging
						max_xy= 0;//auto
						reference_xy = "first frame (default, better for fixed)";	
						selectWindow(Ref); rename("temp"); //NanoJ creates an extra file, kill the old and replace with the new	
						run("F4DR Estimate Drift", "time="+time_xy+" max="+max_xy+" reference=["+reference_xy+"] show_drift_plot apply choose=["+transformationfile+"XY]");	
						rename(Ref);  //print(transformationfile); //debug
						//clean up 
						CloseSelectWindows(newArray("temp", "Drift-X", "Drift-Y", "Drift"));
						transformationfile = transformationfile + "XYDriftTable.njt";
						
						if (Ref != "" && Target != "None") // align Target stack to first images (assume only 1 ref  for this script):pre and post are just  two images -> combine, align to first,  split again and rename; alternately, align stack to single aligner ref 
							{
							rename(Target);
							run("Select All"); run("Duplicate...", "ignore duplicate range=1-1"); rename("Ref"); //here is the assumption Ref is a single image not a stack
							selectWindow(Target); run("Slice Remover", "first=1 last=1 increment=1"); // works whether Target is one image  or stack
							//run("Stack to Images");selectWindow("Temporary-0001"); rename(Ref); selectWindow("Temporary-0002"); rename(Target);
							}
						
						}
					}
				}
				
		return transformationfile; //if generated may be sent back for applying to another image
		}
			
//Function to align images to one another 
function Align4DImage2(CompositeImageName, L_temporarypath, AlignerChannel, L_AlignToSlice, LL_AlignWithNanoJ)
	{
	//only aligns t-stack (frames >1)
	//CurrentBatchMode= is("Batch Mode"); 	//setBatchMode(true);
	// transformation file to be saved locally at tmppath (defined at the top of the macro) so that it does not get overwritten by another computer!
	
	getDimensions(w, h, L_channels, slices, frames);
	if (frames==1) return; //if only one frame, do not try to split to stacks and align 
	
	if(L_channels!=1) run("Split Channels");
	else rename("C1-"+CompositeImageName); //for compatibility
			
	AlignerChannelNumber = parseInt(substring(AlignerChannel, 1, 2)); // is a string can be 0 or one of the 4 (9) channels, if 0 there is no reference,each for itself
	if(Verbosity>1) print("Aligning to " + AlignerChannelNumber);


	//if it is 0, then the reference alignment is not carried out
if(AlignerChannelNumber!=0)
	{//first generate the transformation matrix
	//if (L_AlignToSlice == "last") {selectWindow("C"+AlignerChannelNumber+"-"+CompositeImageName); setSlice(nSlices);}
	TempTransformMatrixFile=AlignStacks(LL_AlignWithNanoJ, "C"+AlignerChannelNumber+"-"+CompositeImageName, L_temporarypath, "None", "[Translation]", " save", L_AlignToSlice);
	//run("MultiStackReg", "stack_1=C"+AlignerChannelNumber+"-"+CompositeImageName+" action_1=Align file_1="+TempTransformMatrixFile+" stack_2=None action_2=Ignore file_2=[] transformation=[Translation] save");
	for (i=1; i< L_channels+1; i++)
		{//align according to reference
		if(i!=AlignerChannelNumber) //run("MultiStackReg", "stack_1=C"+i+"-"+CompositeImageName+" action_1=[Load Transformation File] file_1="+TempTransformMatrixFile+" stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
			TempTransformMatrixFile=AlignStacks(LL_AlignWithNanoJ, "C"+i+"-"+CompositeImageName, TempTransformMatrixFile, "None", "[Translation]", " apply",L_AlignToSlice);
		}
	}
else //align channels independently
	{
	for (i=1; i< L_channels+1; i++) 
		{
		//if (L_AlignToSlice == "last") {selectWindow("C"+i+"-"+CompositeImageName); setSlice(nSlices);}// first slice may have no signal so the default of aligning to this will be a disaster
		//run("MultiStackReg", "stack_1=C"+i+"-"+CompositeImageName+" action_1=Align file_1=[] stack_2=None action_2=Ignore file_2=[] transformation=Translation");
		TempTransformMatrixFile=AlignStacks(LL_AlignWithNanoJ, "C"+i+"-"+CompositeImageName, L_temporarypath, "None", "[Translation]", "",L_AlignToSlice);
		a=File.delete(TempTransformMatrixFile);
		}
	}

	mergestring ="";
	for(i=0; i<L_channels; i++) mergestring = mergestring + "c" + i+1 + "=C"  +  i+1 + "-" +CompositeImageName +  " ";
		
	mergestring=mergestring + "create"; //run("Merge Channels...", "c1="+SignalNamesRGB[0]+" c2="+SignalNamesRGB[1]+" c3="+SignalNamesRGB[2]+" create"); 
			
	if(L_channels!=1) 	run("Merge Channels...", mergestring); 
	else	rename("Merged"); //Merge channels command is just skipped if there is only one file and it ends up with the wrong name, crashing the macro
		
	if(File.exists(TempTransformMatrixFile)) a=File.delete(TempTransformMatrixFile); //setBatchMode(CurrentBatchMode);
	}



function GenerateZstackFromSingleImage(ImageName, SlicesDesired)
{
run("Concatenate...", "  title=[Concatenated Stacks] image1="+ImageName+" image2="+ImageName+" image3=[-- None --]"); //this closes the sources
rename(ImageName); //since the title is no longer used
run("Size...", "depth="+SlicesDesired+" constrain average interpolation=None"); // no need to get  the width and height but I needed min 2 slices with the concatenate to get this working in the macro. probably not needed in  with later IJ versions
}



function ChangeFileExtensions(L_path, from_ext, to_ext)
{
targetfiles=L_path + "*."+ from_ext;
targetfiles=replace(targetfiles, "/",File.separator);
exec("cmd", "/c", "rename", targetfiles, "*."+to_ext);
	}

function BuryFileWithExtensions(L_path, from_ext) //ChangeFileExtensions no longer sufficiently workaround - why?
{
File.makeDirectory(L_path+from_ext);
targetfiles=L_path + "*."+ from_ext;
targetfiles=replace(targetfiles, "/",File.separator);
exec("cmd", "/c", "move", targetfiles, L_path+from_ext);
}





//******** FUNCTION SegmentImages
function SegmentImages(L_SegmentationChannel, L_cytoChannel, L_CalciumChannel, L_UseExistingROIs, L_UseStarDist, well, L_AlignmentFolder,
 L_experimentpath, L_SegmentationFolder, L_SegmentationSettings, L_ErodeCycles, L_BandWidth, 
 UseNoOverlapBands, Group,L_SignalNamesRGB, NumT, FirstT, L_MaxROIs, reportstarted, L_SegmentReportFile) 
//version e for IJ1.51w; this function uses newly generated files by the preprocess function if they were left open
{
//print("called SegmentImages"); print("");
//setBatchMode(true);  should be done around both process and segment so that images are passed silently
if (SegmentationChannel==-1) FatalError("You have not defined a channel for segmentation (channel = -1) but still asked to segment. Please check your settings.");


//hard-coded data collection option here 
// List keys values is more silent but ~5 x slower than using Results table (e.g. up to 4 seconds for 750 timepoints of 50 ROI means)
// Results table The latter can flash on the screen but we can position it off the screen so there is no flashing
// process can occasionally be interrupted by key press if trying to work on something else, is it related to this? Not sure, need to test (MJC 2022-11-14)
// Will collect shape parameters both ways because keys give 35 parameters and I have been using 26 -> need to check if the bigger table breaks downstream analaysis

DataCollectionOption = "ResultsTable"; //"ResultsTable" || "List"


if( NumT !=0) L_WindowTimecourse=true;
else L_WindowTimecourse=false;
if(L_WindowTimecourse) L_Timewindow = "Window_"+FirstT+"to"+FirstT+NumT-1+ File.separator;
else L_Timewindow="";

//create the main segementation folder for the segmentation report file at least
if (!File.exists( L_experimentpath + L_SegmentationFolder)) File.makeDirectory( L_experimentpath + L_SegmentationFolder);  // this is either the only folder or the upper level for window subfolders	

//Generate Report
//reportfile=L_experimentpath + L_SegmentationFolder+File.separator+"Segmentation"+DateStampstring()+".txt";   //Merged files will overwrite so there's no point making a unique ID
if (!reportstarted) File.saveString("Segmenting Data - starting/version "+VersionNumber+ " using IJ version " + IJVersionRunning + "\r\n"+ "\r\n",L_SegmentReportFile);
else  File.append("\r\n",L_SegmentReportFile); 
File.append("Time Window="+L_Timewindow+ "\r\n", L_SegmentReportFile);
File.append("well="+well+ "\r\n", L_SegmentReportFile);
File.append("L_experimentpath="+L_experimentpath+ "\r\n", L_SegmentReportFile);
File.append("Alignment Folder="+L_AlignmentFolder+ "\r\n", L_SegmentReportFile);
File.append("L_SegmentationFolder="+L_SegmentationFolder+ "\r\n", L_SegmentReportFile);
File.append("L_UseStarDist="+L_UseStarDist+ "\r\n", L_SegmentReportFile);
File.append("Channel used for Segmentation="+L_SegmentationChannel+ "\r\n", L_SegmentReportFile);
  SegmentationSettingLabels = newArray("post srqt RB value", "min size", "max size", "smoothing", "watershed", "force square root on single snap");
for(i=0;i<L_SegmentationSettings.length;i++) File.append("L_SegmentationSettings["+i+"],"+SegmentationSettingLabels[i]+"="+L_SegmentationSettings[i] + ", ", L_SegmentReportFile);
File.append("\r\n", L_SegmentReportFile);
File.append("ErodeCycles to separate nuclei and cytoplasm="+L_ErodeCycles+ "\r\n", L_SegmentReportFile);
File.append("Width of band for collecting cytoplasm signal="+L_BandWidth+ "\r\n", L_SegmentReportFile);
File.append("Group="+Group+ "\r\n", L_SegmentReportFile);
File.append("Analysing by time window?="+WindowTimecourse+ "\r\n", L_SegmentReportFile);
File.append("Number of Timepoints in current window="+NumT+ "\r\n", L_SegmentReportFile);
File.append("First Timepoint in current window="+FirstT+ "\r\n", L_SegmentReportFile);
File.append("Max number of ROIs permitted="+L_MaxROIs+ "\r\n", L_SegmentReportFile);

//end report
if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");}
if (isOpen("Results")) { selectWindow("Results"); run("Close");} 

				
//define save path that includes window info if needed
SavePath = L_experimentpath + L_SegmentationFolder+ File.separator + L_Timewindow; if (!File.exists(SavePath)) File.makeDirectory(SavePath);  
print(""); print( L_experimentpath + L_SegmentationFolder); 

MergedFile = L_experimentpath + L_AlignmentFolder+L_Timewindow + "Merged"+well+".tif";
FastCa = L_experimentpath + L_AlignmentFolder+L_Timewindow + "FastCa"+well+".tif";
//CurrentTimewindowDir = L_experimentpath+ "Window_"+FirstT+"to"+FirstT+NumT-1 + File.separator;
//CurrentTimewindowDir = L_experimentpath; //so use CurrentTimewindowDir even if there is one (i.e. no) windowing.
	


print(printformatter+ "Segmenting channel #" +L_SegmentationChannel + " of well " + CurrentWell + " at "+ MergedFile); 	
	
if (Verbosity >2) print("Path used for saving is "+ SavePath);	

// check if needed images are already open
if (!isOpen("Merged"+well+".tif"))
	{
	if (File.exists(MergedFile) != 1) {print(MergedFile + " does not exist. Will try next well."); return 0;} // skip to next well
	open(MergedFile);
	}


//Step 1 - find the ROIs
selectWindow("Merged"+well+".tif");	
ImageWidth= getWidth(); ImageHeight = getHeight(); //needed later to identify zero-size bad ROIs

if(Channels!=1) 
	run("Split Channels");
else
  rename("C1-Merged"+well+".tif");

// maxproj function handling 1-n frames, tagged as nuclei or cyto
targetimage= "C" + L_SegmentationChannel + "-Merged" + well + ".tif";
returnMaxProjection(targetimage, "nuclei"); //selectWindow("C" + L_SegmentationChannel + "-Merged" + well + ".tif");


function returnMaxProjection(target, L_compartment)
	{
	selectWindow(target);
	nFramestoSegment=nSlices;
	if (nFramestoSegment!=1) //catch error when there happens to be only a single plane in the experiment 
		{
		run("Z Project...", "projection=[Max Intensity]");rename("MAXproj_"+L_compartment);
		}
	else
		{
		run("Select All"); run("Duplicate...", "title=MAXproj_"+L_compartment);
		//if(CondenseFactor==1) run("Duplicate...", "title=SubstituteForFastCalcium");//if there is only one timepoint then the "max projection" was actually a simple copy and it will do here too
		//this is addressed later, it is not appropriate here because segmentation channel may not be calcium
		}
	}	

if(!L_UseExistingROIs)
	{			
		
	//THE ROIs ARE GENERATED HERE. If we want to use old ROIs already saved, then we skip this section.	
	selectWindow("MAXproj_nuclei");	
	getDimensions(imagewidth, imageheight, mergechannels, slices, frames); 
	nFramestoSegment=nSlices;
		
	ForceSquareRoot = L_SegmentationSettings[5];	// square root can even out cell intensities across image 
	//don't run square root if source image is noisy - here deciding based on input files >1 as it is conserved for whole dataset. Could be based on image but it might chnage from one to next..
		
	if (CalciumChannel != -1) 
		{NumberOfSourceFrames =CondenseFactor*nFramestoSegment;}
	else 
		{NumberOfSourceFrames=nFramestoSegment;} // if no calcium channel, Condensefactor may have been ignored and not set

		
		//Now ForceSquareRoot is +1 on,  0 default or -1 prevent. Default isoff for single frame and off for StarDist and, for conventional, on unless single frame
		SquareRootTheImage = ((!L_UseStarDist && NumberOfSourceFrames!=1 && ForceSquareRoot==0)  || (ForceSquareRoot==1));
		if(SquareRootTheImage) run("Square Root"); //this generates 1E3+ROIs from noisy single image conventionally, cannot be used
		smooth = L_SegmentationSettings[3];// smooth = "median_radius3"; or 5  // User selected because depends on Compression as well, if this is <5 then we likely need this.
		saveAs("Tiff", SavePath + "Segmentation"+well+".tif"); //  now save the segmentation image
		rename("MAXproj_nuclei");
		
		
		band_width =L_BandWidth;//1; // this is in calibrated units (um) - since v5d29f, it is  a modifiable parameter


		if (!L_UseStarDist)
			{
			//be sure scale properties are correct so band is going to be 1 pixel not 1 inch wide! Needs PixelSizePostBin
			//run("Properties...", "channels=1 slices=1 frames="+nSlices+" unit=um pixel_width="+PixelSizePostBin +" pixel_height="+PixelSizePostBin +" voxel_depth=1 frame=[1 min]");	
			Watershed= L_SegmentationSettings[4];
			getNuclearROI(L_SegmentationSettings[1], L_SegmentationSettings[2], "MAXproj_nuclei", smooth, L_SegmentationSettings[0], Watershed);
			}
		else
			{
			getPixelSize(unit, pixelWidth, pixelHeight);
			// Stardist was defining ROIs over the edge, crashing the make band, even with excludeBoundary 2 or half of the sqrt(max size)+ some. THerefore added to the removal filter
			MaxBoundaryProximity= 2;//*(1+floor((Math.sqrt(L_SegmentationSettings[2])/2)/pixelWidth));//4 + 1+floor((Math.sqrt(L_SegmentationSettings[2])/2)/pixelWidth);
			args="['input':'MAXproj_nuclei', 'modelChoice':'Versatile (fluorescent nuclei)', 'normalizeInput':'true', 'percentileBottom':'1.0','percentileTop':'99.8',";
			args=args+"'probThresh':'0.5', 'nmsThresh':'0.0', 'outputType':'ROI Manager', 'nTiles':'1',	'excludeBoundary':'" + MaxBoundaryProximity + "',";
			args=args+" 'roiPosition':'Automatic', 'verbose':'false','showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]";
			run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args="+args);
			selectWindow("MAXproj_nuclei");
			// remove ROIs that fail to satisfy criteria 
			// i) user-defined size constraints (in um^2)
			// ii) all points far enough from edge that the make band will not crash the script
			UnFilteredROIs = roiManager("count");
			print("UnfilteredROIs detected by stardist="+UnFilteredROIs);
			xminLimit= 0;//+1+floor(band_width/pixelWidth);
			yminLimit=xminLimit;
			xmaxLimit=imagewidth-1;//+floor(band_width/pixelWidth);
			ymaxLimit=imageheight-1;//+floor(band_width/pixelHeight);
			ROIsOutOfBounds=0; ROIsTooLarge=0;ROIsTooSmall=0;
		
			for (ROI=UnFilteredROIs; ROI >0; ROI--)
				{
				roiManager("Select", ROI-1); //first is "0", starting at last so no renumbering issues in deletion
				//checking all settings first to permit the else if series here; could be faster to define functions to call only as needed?
				getSelectionBounds(xmin, ymin,w,h); xmax=xmin+w; ymax=ymin+h; //about 20% faster than using getStatistics
				area=getValue("Area"); //this is in calbrated units in image properties)
				if ((xmin<xminLimit) || (xmax>xmaxLimit)) {ROIsOutOfBounds++; roiManager("Delete");}
				else if (ymin<yminLimit || ymax>ymaxLimit) {ROIsOutOfBounds++; roiManager("Delete");}
				else if ((area > L_SegmentationSettings[2])) {ROIsTooLarge ++; roiManager("Delete");}
				else if ((area < L_SegmentationSettings[1])) {ROIsTooSmall ++; roiManager("Delete");}
				//else print(ROI, xmin,xmax, ymin, ymax);
				}
			if (ROIsOutOfBounds !=0) print("Removed " + ROIsOutOfBounds + " ROIs from stardist that had pixels over the edge of the image");
			print("Removed " + ROIsTooLarge + " ROIs identified by stardist that were larger than user-specified size limits");
			print("Removed " + ROIsTooSmall + " ROIs identified by stardist that were smaller than user-specified size limits");	
			}	
		FilteredROIs = roiManager("count"); print("Remaining ROIs="+FilteredROIs);
	

	//save Original ROI set - this is all possible ROIs obtained from the calcium probe localised to the nucleus.
	// later these ROIs will be shrunk and some ROIs will be discarded, the remaining ROIs will be used to generate cytoplasm bands that correspond to the nuclear zones
	//so the number of ROIs in the original set is higher than the others
	// a "trimmed" version is saved that has the surviving ROIs at original size

		OriginalNumberOfROIs = roiManager("count");  // if this is too many, save the list for the record but make a decision after
		if (OriginalNumberOfROIs > L_MaxROIs) 
			{	
			roiManager("reset"); // choice here either limit to max or quit
			OriginalNumberOfROIs=0;
			print("More ROIs than the limit you set, something is probably wrong with the settings. The list was set to zero");
			}
		
		if (Verbosity >1) print(OriginalNumberOfROIs + " ROIs found in well " + well);
		
		if (Verbosity >3) print("Starting with " + roiManager("Count") + " ROIs"); 
		if (OriginalNumberOfROIs==0) {
				if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");}
				print("There are no ROIs detected for well " + well + " in " + MergedFile  + ". Moving to next well."); 			
				run("Close All"); 
				//setBatchMode(false);  handled in calling function
				return 0;
					}	
					
		if (OriginalNumberOfROIs!=0)
			{
			roiManager("Save", SavePath + "ROIoriginal"+well+".zip");
			if (Verbosity >3) print(SavePath + "ROIoriginal"+well+".zip");
			}
			
		NumberOfROIsRemaining = OriginalNumberOfROIs;

		// Delete nuclear ROIs too small to survive an erode - loop 
		//for (ROI=0; ROI<OriginalNumberOfROIs;  ROI++) 
		if (L_ErodeCycles>0)
			{
			for (ROI=OriginalNumberOfROIs; ROI >0; ROI--)
				{			
				selectWindow("MAXproj_nuclei");
				currentROI = ROI-1;//ROI-(OriginalNumberOfROIs-NumberOfROIsRemaining);//if ROIs are deleted the current position should reflect that the remaining ROIs have moved up the list
				roiManager("select", currentROI);
				if (Verbosity >3) {print("creating mask from ROI #"+currentROI); print("there are now " +roiManager("count")+ " ROIs in the list"); }
				//erode has to be on 8 bit image and cannot directy operate on ROI selection
				run("Create Mask"); for (i=0; i< L_ErodeCycles; i++) run("Erode");
				run("Create Selection"); 
				getSelectionBounds(x,y,w,h); 
				if (Verbosity >3) {print (x,y,w,h, imagewidth, imageheight,ROI + " ROIs so far");}
				if ((x==0) &&(y==0) &&(w==imagewidth) && (h==imageheight)) //remove the original now if it is too small to erode by the specified amount
					{
					roiManager("select", currentROI); roiManager("Delete"); 
					if (Verbosity >3) {print(x + "," + y+ "," +w+ "," +h, "deleting ROI #"+ROI); print("there are now " +roiManager("count")+ " ROIs in the list");}
					}
				selectWindow("Mask");close();//closes the mask window
				}
			}

			
		//save trimmed ROI set, these are the ones we can work with
		// this set could be used to collect calcium data also
		 // delete all ROIs or ROI manager accumulates with future ROIs
		if (roiManager("Count")!=0) {roiManager("Save",SavePath + "ROItrimmed"+well+".zip"); roiManager("Select All"); roiManager("Delete");}
		if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");} //without delete, ROI manager accumulates all ROIs

		if (File.exists(SavePath + "ROItrimmed"+well+".zip") != 1) 
			{
			if (Verbosity >0) print("There are no ROIs detected for " + MergedFile + " after trimming. Moving to next well."); 
			run("Close All"); return 0;  //leave function as there is nothing more to do
			}
	
		// now we can work with the trimmed ROI list
		// NB use no overlap bands only relevant for cyto
		CreateROIs("Nuclear", SavePath , well, "MAXproj_nuclei", L_ErodeCycles, band_width, UseNoOverlapBands);//create nuclear ROIs using parameters L_experimentpath, well, MAXproj_nuclei, ErodeCycles

//*/ //DEBUG		
		
		if (!UseNoOverlapBands) // conventional bands as we used before
					CreateROIs("Cytoplasm", SavePath , well, "MAXproj_nuclei", L_ErodeCycles, band_width, UseNoOverlapBands);//create cytoplasm ROIs using parameters L_experimentpath, well, MAXproj_nuclei, ErodeCycles
		else
			{
			// need to generate a cyto image here - make a copy and modify because the original is quantified later
			sourceformaxcyto= "C" + L_cytoChannel + "-Merged" + well + ".tif";
//DEBUG - the channel is hard coded to #2 at the moment
				selectWindow(sourceformaxcyto);
				run("Select All"); //in case caller left random selection on the image, this is not currently supported
				run("Duplicate...", "title=forMaxcyto");
				sourceformaxcyto="forMaxcyto"; // now the existing data image is freed
			selectWindow(sourceformaxcyto);
			//run("Subtract Background...", "rolling=50");
			run("Median...", "radius=2"); //needed or get a lot of little dots?
			returnMaxProjection(sourceformaxcyto, "cyto"); // returns as MAXproj_cyto
			saveAs("Tiff", SavePath + "SegmentationCyto"+well+".tif"); //  now save the segmentation image
			rename("MAXproj_cyto");
			//create AND save cytoplasm ROIs using parameters L_experimentpath, well, MAXproj_nuclei, ErodeCycles
			CreateROIs("Cytoplasm", SavePath , well, "MAXproj_cyto", L_ErodeCycles, band_width, UseNoOverlapBands);
			CreateROIs("Soma", SavePath , well, "MAXproj_cyto", L_ErodeCycles, band_width, UseNoOverlapBands);
			
			selectWindow(sourceformaxcyto); close();
			selectWindow("MAXproj_cyto"); close();
			}		
		//now should have initial trimmed ROIs, shrunken nuclear ROIs and, band ROIs. Keep all for now as they are probably not optimal
	}
	//THE ROIs HAVE BEEN GENERATED AND SAVED. If we want to use old ROIs already saved, then we come back here.
	
	
	

// RENAMING split channels here because may skip next step
//  treating all channels the same to generate cyt and nuc data in all cases,  regardless of whether they are coompartment restricted or spatial ratio channels
//should collect intensity data as well - here is only intensity data and ratios are generated later
	for(currentchannel=0;currentchannel<Channels;currentchannel++ ) 
		{selectWindow("C"+currentchannel+1+"-Merged" + well + ".tif");rename(L_SignalNamesRGB[currentchannel]+well+".tif");}
		
	//HERE ONWARDS - data is collected from the ROIs
	
	// first check they still exist after possible removal with the adaptive segmentation
	if (File.exists(SavePath + "ROI"+"nuc"+well+".zip") )
		{
		//FIRST - shape parameters
		selectWindow("MAXproj_nuclei"); //can use this single timepoint to  collect ROI shape data for all ROI types // to get shape data expand the measurements types at this point
		//run("Set Measurements...", "area mean standard modal min centroid center perimeter fit shape feret's median skewness kurtosis area_fraction redirect=None decimal=3");
		run("Set Measurements...", "area mean standard modal min centroid center perimeter fit shape feret's median skewness kurtosis redirect=None decimal=3");
		roiManager("Open", SavePath + "ROI"+"trimmed"+well+".zip");
		//Keys = newArray("Area", "Mean", "StdDev", "Mode", "Min", "Max", "X", "Y", "XM", "YM", "Perim.", "Major", "Minor", "Angle", "Circ",  "Feret", "FeretAngle", "FeretX", "FeretY", "FeretAngle", "Skew", "Kurt", "AR", "Round", "Solidity");
			
			// Results table option - it is faster but screen may flash
			t1=getTime();
			roiManager("multi-measure measure_all"); //puts one ROI per row into a results table to simplify access to parameters by ROI
			firstrun_hideresultstable= true;
			if (firstrun_hideresultstable) //do this once only because it is a slow function
				{
				firstrun_hideresultstable=false;
				if(isOpen("Results")) {selectWindow("Results"); setLocation(screenWidth, screenHeight);} 
				}
			filetosave= SavePath + "Results"+well+"ROI-SpatialFeaturesFromCaMAXproj";	
			if (Verbosity >3) print("Saving "+filetosave+".xls");	
			saveAs("Results", filetosave+".xls"); //saving compartment  data output
			
			if (Verbosity >3) print("ROI data to results to file took " + getTime()-t1 + "ms");
		
		
		
			// Specifically for shapes - 35 parameters here 
			// this is 5x slower than using the results table!
			//if (File.exists(filetosave + ".csv")) a=File.delete(filetosave + ".csv"); // removal of existing file needed if use only append
			t1=getTime();
			NumROIs= roiManager("count");
			for (ROI=0;ROI<NumROIs; ROI++)
				{
				roiManager("select", ROI); 	
				List.setMeasurements ;   //35 values
				List.toArrays(keys, values);
				if (ROI==0)
					{
					NumberOfValues = List.size ;
					header = "ROIs/ShapeParameters:";
					for (i=0;i<NumberOfValues; i++) {header= header + ","+ keys[i] ;}
					File.saveString(header+"\n", filetosave + ".csv") ; // set as csv
					}
				ValueDataString= toString(ROI+1);
				for (i=0;i<NumberOfValues; i++) {ValueDataString= ValueDataString + ","+ values[i];}
				File.append(ValueDataString, filetosave + ".csv") ; // set as csv
				}	
			if (Verbosity >3) print("ROI data to file using keys took " + getTime()-t1 + "ms");	
			
			
			
			//v=getVersion(); vn=parseFloat(substring(v,lengthOf(v)-5, lengthOf(v)-1));
			//if(vn>1.51) 	Table.rename( "Results"+well+"ROI-SpatialFeaturesFromCaMAXproj"+".xls", "Results"); //v1.52a onwards allows all kinds of table names
			//If there's only a single time point, still need a calcium frame to substitute for the fast calcium lower down
			
					
			killROImanager();
			
			
		//Now ANALYSE any condensed  CALCIUM DATA, as well as a faster version  LATER
		
		// here need parameters Channels, SignalNamesRGBgroups and passed Group
		
		
		
		
		//set the measurement parameters for ktrs, area etc for QC is in the shaped data, e.g. to check if  erosion is too extreme. 
		//Open the nuclear ROIs and append ERK-p38-Ca data as a single file
		//firstrun_hideresults= true; - already done later
		
		run("Set Measurements...", "mean redirect=None decimal=3"); //now we have a separate shape file, no need for areas here
		//ROItype=newArray("nuc", "band");//NB compartment is nuc and cyt but I need nuc and band!
		
		for(currentcompartment=0;currentcompartment<compartment.length;currentcompartment++ )
			{//EACH COMPARTMENT
			roiManager("Open", SavePath + "ROI"+compartment[currentcompartment]+well+".zip");
			//Now treat all channels the same - but this is the condensed Ca and should be saved as such or it will be over-written later
			for(currentchannel=0;currentchannel<Channels;currentchannel++ )
				{//EACH CHANNEL
				CondensedChannelIndicator=""; if ((L_SignalNamesRGB[currentchannel]=="Ca") && (CondenseFactor!=1))  CondensedChannelIndicator="Condensed"; //don't say Condensed if it is not!
				if (Verbosity >1) print("Quantifying "+ roiManager("count")* nSlices + " ROIs");
				selectWindow(L_SignalNamesRGB[currentchannel]+well+".tif");
				filenametosave=	"Results"+well+CondensedChannelIndicator+L_SignalNamesRGB[currentchannel]+compartment[currentcompartment]; //+".xls";	
				// two options here, Results table flashes on the screen even in Batch Mode, but List/keys is many times slower
				SaveDataFromSelected2Dtimecourse(DataCollectionOption, Verbosity, SavePath+filenametosave+".xls");
				//SaveDataFromSelected2Dtimecourse(DataCollectionOption, Verbosity, SavePath+filenametosave+".csv");
			}	
			killROImanager();
			}
		
		
		if((CalciumChannel!=-1)&&(CondenseFactor==1))  //get a fastCa substitute from the merged channels if necessary
			{selectWindow(L_SignalNamesRGB[CalciumChannel-1]+well+".tif"); 	run("Duplicate...", "title=SubstituteForFastCalcium" +" duplicate");}
		
		
		
		if(CalciumChannel!=-1) 
			{
			if(CondenseFactor!=1) //open the FastCa stack, naming with window indicators handled above
				{ 
				if (!isOpen("FastCa"+well+".tif"))
					{
					if (File.exists(FastCa) != 1) {print("WARNING: did not find FastCa file at " + FastCa); print(""); return 0;} // skip to next well
					open(FastCa);
					}
				selectWindow("FastCa"+well+".tif");
				}
				else selectWindow("SubstituteForFastCalcium"); //this was not generated earlier from the calcium frame, when there is only 1 and will do for the next steps
					
			
				rename("Fastcalcium"+well+".tif");
				currentchannel=CalciumChannel-1;//2;//calcium	
		
			run("Set Measurements...", "mean redirect=None decimal=3"); //now we have a separate shape file, no need for areas here
		
			//open the "trimmed ROI", this is the nuclear ROI before erosion to get moreaveraged Ca data from NLS Ca-probe; for untargeted us the nuc and band data)
			//***this gave us a bug before v5d15editing
			roiManager("Open",SavePath + "ROItrimmed"+well+".zip")
			selectWindow("Fastcalcium"+well+".tif");	
			filenametosave=	"Results"+well+L_SignalNamesRGB[L_CalciumChannel-1]+"bignuc";//"Cabignuc";
		
			// two options here, Results table flashes on the screen even in Batch Mode, but List/keys is many times slower. We move the Results table off the window
			SaveDataFromSelected2Dtimecourse(DataCollectionOption, Verbosity, SavePath+filenametosave+".xls");
			//SaveDataFromSelected2Dtimecourse("List", Verbosity, SavePath+filenametosave+".csv");	
			killROImanager();
				
			for(currentcompartment=0;currentcompartment<compartment.length;currentcompartment++ ) //data acquisition on fastCa, so do not collect on compressed data above because it will be overwritten
				{
				roiManager("Open", SavePath + "ROI"+compartment[currentcompartment]+well+".zip");
				selectWindow("Fastcalcium"+well+".tif");
				filenametosave=	"Results"+well+L_SignalNamesRGB[currentchannel]+compartment[currentcompartment];
				SaveDataFromSelected2Dtimecourse(DataCollectionOption, Verbosity, SavePath+filenametosave+".xls");	
				killROImanager();
				}
				selectWindow("Fastcalcium"+well+".tif");close();
		}
	
	selectWindow("Results"); run("Close"); 
	}
	
	//I moved this from the above loop as it was getting left behind
	selectWindow("MAXproj_nuclei");	//   segmentation image saved earlier
			run("Close");
			
			
	//close all merged channels outside the  conditional loop
	for(currentchannel=0;currentchannel<Channels;currentchannel++) //{selectWindow(L_SignalNamesRGB[currentchannel]+well+".tif"); close();} // when using F4DR, may need to close 3 times
		{Target= L_SignalNamesRGB[currentchannel]+well+".tif";fullyClose(Target); }// on some versions e.g. 1.53s get NAN if try to assemble string in the function call, even if use toString(L_SignalNamesRGB[currentchannel])+well+".tif");} // toString is needed as  L_SignalNamesRGB[currentchannel] was coming back as NaN. still had trouble with v1 of function, though  verbose version below worked OK
	
	print(printformatter +"ROI expand and band completed for Well" + CurrentWell + " in "+ MergedFile);
		if (Verbosity >2) print("");
	
}


function SaveDataFromSelected2Dtimecourse(Method, L_verbosity,  savenameandpath)
{
	// now the Method is hard-coded at the top of the Segmentation function, because I think the results table is much faster 
	verbosity_limit= 2;
	t1= getTime();
	if (Method=="ResultsTable")
	{
		roiManager("Multi Measure");
		if (firstrun_hideresultstable) //do this once only because it is a slow function
			{
			firstrun_hideresultstable=false;
			if(isOpen("Results")) {selectWindow("Results"); setLocation(screenWidth, screenHeight);} 
			}
			if (L_verbosity >verbosity_limit) print("Saving " +savenameandpath);
			saveAs("Results", savenameandpath); //saving compartment  data output
			if (L_verbosity >verbosity_limit) print("ROI data to results to file took " + getTime()-t1 + "ms");
		}
	else if (Method =="List") // alternative // Shifting to avoid use of Results table, just a duplication for now
		{
		t1=getTime();
		header= "time/mean of ROI:"; for (ROI=0;ROI<NumROIs; ROI++) header=header+"," + ROI; 
		File.saveString(header+"\n", savenameandpath) ; // set as csv, saveString replaces any existing file
		for (t=0; t<nSlices; t++) 
			{
			setSlice(t+1); ROIValuesCurrentTime = toString(t);
			for (ROI=0;ROI<NumROIs; ROI++) {roiManager("select", ROI); ROIValuesCurrentTime=ROIValuesCurrentTime + "," + getValue("Mean");} 	
			File.append(ROIValuesCurrentTime, savenameandpath) ; // set as csv
			}
		if (L_verbosity >verbosity_limit) print("ROI data to file using List took " + getTime()-t1 + "ms");	
		}
	else FatalError("Function Call Typo - SaveDataFromSelected2Dtimecourse");
}



function getNuclearROI(min, max, ImagetoSegment, L_smooth, L_RBradius, L_Watershed)
{
//run("Nucleus Counter", "smallest="+L_SegmentationSettings[1]+" largest="+L_SegmentationSettings[2]+" threshold=Otsu smooth=None subtract watershed add");
selectWindow(ImagetoSegment);
run("Select All"); //in case caller left random selection, not currently supported
run("Duplicate...", "title=temp");
if (L_RBradius >0) run("Subtract Background...", "rolling="+L_RBradius); // -1 means don't run RB, for sme expts choose this to  avoid detecting spurious particles
if(L_smooth=="median_radius3") run("Median...", "radius=3"); //nothing else on offer right now
if(L_smooth=="median_radius5") run("Median...", "radius=5"); //nothing else on offer right now

run("OtsuThresholding 16Bit");
//getThreshold(minthreshold,maxthreshold); not needed?
run("Convert to Mask");
if(L_Watershed) run("Watershed");
setThreshold(128, 255);
analyseStr = "size=" + min +"-" + max +" circularity=0.00-1.00 show=";
		analyseStr+="Nothing";
		analyseStr+=" exclude clear";
run("Analyze Particles...",   analyseStr+ " add");
selectWindow("temp");close();
}



//******** FUNCTION CreateROIs(Compartment...
function CreateROIs(L_Compartment, Path, CurrentWell, image, NumberofErodeCycles,L_band_width, L_NoOverlapBands)//band_width is in calibrated units (um) 
	{
print("CreatingROI type " + L_Compartment);		
//DEBUG adding a new compartment option here "Soma"
	run("Options...", "iterations=1 count=1"); // this prevents band selections from ending up as the entire field outside the band
	//setBatchMode("exit and display");
	
	
	
	if ((L_Compartment == "Nuclear") || !L_NoOverlapBands) // i.e. if overlap allowed, band also generated this way, otherwise it is only for nuc
		{
	roiManager("Open", Path + "\\ROItrimmed"+CurrentWell+".zip");
	NumberOfROIs = roiManager("count"); 
	if (Verbosity >2) print("Trimmed list contains "+roiManager("count")+ " ROIs. Will find and exclude non-erodable ROIs.");
	
		if (L_Compartment == "Nuclear") print(printformatter + "eroding nuc");
		for (ROI=0; ROI <NumberOfROIs; ROI++)
			{				
			selectWindow(image);
			roiManager("select", ROI);//0);//take first to generate replacement at end //  no, roiManager("Update") is simpler
			if (L_Compartment == "Nuclear") 
				{
				run("Create Mask"); 
				for (i=0; i< NumberofErodeCycles; i++)  run("Erode");
				}
			else if (L_Compartment == "Cytoplasm")
				{run("Make Band...", "band="+L_band_width); run("Create Mask");}  //consider {run("Make Band...", "band="+L_BandWidth);run("Create Mask");run("Erode");} //single erode but from both directions 
			else FatalError("illegal compartment parameter. Only Nuclear and Cytoplasm allowed, but we have '"+L_Compartment+"'");
					
			run("Create Selection"); 
			roiManager("Update");	/*roiManager("Add");  roiManager("select", 0); roiManager("Delete");*///  roiManager("Update") is simpler
			selectWindow("Mask");close();
			} //end ROI loop
		}
	else // here we have selected (cytoplasm OR soma) AND L_NoOverlapBands - experimental algorithm to avoid overlap between larger band ROIs
		{	
		//Bands_without_overlap(image, L_band_width, NumberofErodeCycles); //
		// image and bandwidth passed, paths can be constructed here. Threshold I am just making up for now
		erosion_cycles=0;// set cyto erode cycles to zero here because we are using ROItrimmed as seeds and they haven't been eroded yet
		// need thresholds here, and paths
		nucROIpath=Path + "\\ROInuc"+well+".zip";// the trimmed list is open, we need to open the eroded one later //Path + "\\ROItrimmed"+CurrentWell+".zip"; // note this one was opened at the beginning of the function
		ROI_outpath_nuc=Path + "\\ROInuc"+well+".zip"; // this is the same as the input path - check this makes sense
		// not all the next 3 needed, but to reuse the function for bands and soma we can do it this way
		ROI_outpath_cyto=Path + "\\ROIband"+well+".zip";
		ROI_outpath_band=Path + "\\ROIbandFull"+well+".zip";
		ROI_outpath_soma=Path + "\\ROIsoma"+well+".zip"; 
		ROI_outpath_somamax=Path + "\\ROIsomamax"+well+".zip"; 
//DEBUG - the minCytThreshold, maxCytThreshold are hard coded at the moment
		minCytThreshold=20; 	maxCytThreshold= 3500; //EDIT - THIS SHOULD BE USER INPUT!
		// image should be smoothed and b-subbed
		if (L_Compartment=="Cytoplasm")
			{
			roiManager("Open", Path + "\\ROItrimmed"+CurrentWell+".zip");
			//NumberOfROIs = roiManager("count"); 
				GenerateCytoBandsOrSomaFromNucSeeds(L_Compartment, image, L_band_width,  erosion_cycles, minCytThreshold, maxCytThreshold, nucROIpath, ROI_outpath_band,  ROI_outpath_cyto, ROI_outpath_nuc);
			}
// at this point we should have the nuc open not the trimmed. What is open?	
		if (L_Compartment=="Soma") 
		{
	roiManager("Open", Path + "\\ROInuc"+CurrentWell+".zip");
			//NumberOfROIs = roiManager("count"); 
			GenerateCytoBandsOrSomaFromNucSeeds(L_Compartment, image, L_band_width,  erosion_cycles, minCytThreshold, maxCytThreshold, nucROIpath, ROI_outpath_somamax ,ROI_outpath_soma, ROI_outpath_nuc);
		}
		}
		
	if (Verbosity >3) print(roiManager("count") + " ROIs");
	
	if (roiManager("Count")!=0 && !(L_Compartment != "Nuclear" && L_NoOverlapBands))  // if we are defining cytoplasm with overlap, this is all done already
	 	{
		if (L_Compartment == "Nuclear") 
	 		 roiManager("Save",Path + "\\ROInuc"+well+".zip"); 
		else if (L_Compartment == "Cytoplasm" && !L_NoOverlapBands)
			roiManager("Save",Path + "\\ROIband"+well+".zip");	
			
		else FatalError("illegal compartment parameter. Only Nuclear and Cytoplasm allowed, but we have '"+L_Compartment+"'");
		}
	killROImanager();
	
	}

//
// this function generates the bands based on roiManager content
function GenerateCytoBandsOrSomaFromNucSeeds(LL_Compartment, image_for_cyto_threshold, maximum_distance_from_nuc_edge, cyto_erosion_cycles, 
minimumCytoThreshold, maximumCytoThreshold, nucROIpath, L_ROI_outpath_maxextent, L_ROI_outpath_cytosoma, L_ROI_outpath_nuc)
	{//setBatchMode("exit and display");		
	//trimmed nuc list already opened
	// this function generates the max extent of the cyto or soma ROIs
	BandsOrSoma_without_overlap(LL_Compartment, image_for_cyto_threshold, maximum_distance_from_nuc_edge,  cyto_erosion_cycles);
	// next function shapes ROIs to a given thresholded image - // seems to work 2023-11-07
	selectWindow(image_for_cyto_threshold);
	blackOutside(); // blacks out everything not already in the ROIs from the above band function
	//if (LL_Compartment=="Cytoplasm")
	roiManager("Save", L_ROI_outpath_maxextent);// this should contain large bands without overlap that need shrinking
print("Saving " + L_ROI_outpath_maxextent + " counts are "+ roiManager("count"));


//DEBUG"""""""""""""" something wrong here because soma starting with number in trimmed not nuc
	//roiManager("Save", L_ROI_outpath_cytosoma+"X.zip");	
	// now the cyto-bands are thresholded based on intensities in the image currently selected
//DEBUG"""""""""""""" next command replaces soma  with bands, cannot see why
	ROIsToDelete=ThresholdROIs(minimumCytoThreshold, maximumCytoThreshold); // this returns an array of which nuc ROIs should be removed for pairing with cyto ROIs
print("Saving " + L_ROI_outpath_cytosoma+"X.zip" + " counts are "+ roiManager("count"));	
roiManager("Save", L_ROI_outpath_cytosoma+"X.zip");	
print(roiManager("count"));
print("**");
	// if there is no cyto signal this may remove all rois or at least require removal of some
	// soma ROI calculated same way as cyto but afterwards, so it is not possible to require further removal - below only applies to cyto
//roiManager("Save", L_ROI_outpath_cytosoma+"X.zip");
	//first save the ROIs
	if (roiManager("count") >0)
			{
			//save the resulting cyto ROIs; note if any were below threshold they will not exist in this list but need to be taken out of the nuc list
			roiManager("Save", L_ROI_outpath_cytosoma);// these are resahped according to the image data
			roiManager("deselect");roiManager("delete"); // isOpen("ROI Manager") fails here
			}
	
	//now create the updated nuc file in case some need deleting
	// normal behavior here is to open the file and save it again even if nothing to delete, if nucROIpath == L_ROI_outpath_nuc, to give possibility to keep the original elsewhere
	if( LL_Compartment=="Cytoplasm")
		{
		if (roiManager("count") >0)
			{
			// get the original nuc ROI file and remove the extras. Make space for it and save the new nucROI fil
			roiManager("Open", nucROIpath); // this should be the eroded list that we need to further exclude samples from
			//print(nucROIpath)		//print(roiManager("count") + " ROIs remaining"); 
			// avoid combining ROI lists
			if (File.exists(L_ROI_outpath_nuc)) File.delete(L_ROI_outpath_nuc);//); // avoid combining ROI lists
			if (ROIsToDelete.length >0) //if there is something to delete
				{
	//print(roiManager("count"));Array.print(ROIsToDelete);print(ROIsToDelete.length);
				roiManager("select", ROIsToDelete); roiManager("delete");
	//print(roiManager("count") + " ROIs remaining"); print("New ROI file at "+ "C:/temp/"+"new.zip");
				roiManager("Save", L_ROI_outpath_nuc);//"+"newnuc.zip");
				}
			else {roiManager("Save", L_ROI_outpath_nuc); }// +"newnuc.zip"); //just copy it here -  in another implementation there is nothing to do in this case
			}
		
		}
//print("nuc is " + L_ROI_outpath_nuc);	print("");
roiManager("deselect");roiManager("delete");
	return;
	
	
	// internal functions below
	function BandsOrSoma_without_overlap(LLL_Compartment, template_image, max_distance, erosion_count)
		// this takes a ROImanager list of seeds (nuclei) and expands them all in a non-overlapping way
		//N.B. if initial seeds overlap, there will be trouble! Seems to be OK if they are just touching
		//ROImanager ends up with the band ROIs
		{
print("running BandsOrSoma for "+	LLL_Compartment);		
		initial_colour = getValue("color.foreground");// temporarily save foreground to ensure fill generates an objective
		setForegroundColor(255, 255, 255);
	
		//create new image of correct size to work with masks
		 	selectWindow(template_image);
		 	getDimensions(width, height, channels, slices, frames);
		 	newImage("Seeds", "16-bit black", width, height, 1);
	
		//show all ROIs and burn them into the seeds image
			roiManager("Fill");//show all ROIs listed as white
		// shade the surrounding pixels according to distance from ROIs
				setOption("BlackBackground", true);
				run("Make Binary");
			//run voronoi on a copy	and solidify all boundaries
				run("Select All"); run("Duplicate...", "title=Voronoi");
				run("Voronoi");	run("Invert");
				setThreshold(254, 255, "raw");
				run("Convert to Mask");//thresholded area to white, expanded seeds in black
					run("Gaussian Blur...", "sigma=3");
					setThreshold(254, 255, "raw");
					run("Convert to Mask");//thresholded area to white, expanded seeds in black
					run("Voronoi");run("Invert");
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
		
		// draw a line between the expanded seeds using the Voronoi
			imageCalculator("AND create", "Seeds","Voronoi");
			rename("delimiter_masks");
		
		//clean up	
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
			run("Create Mask"); rename("compartment"); //new image showing max non-overlapping bounds of current ROI
			// if (LLL_Compartment=="Cytoplasm") the nucleus should be excluded otherwise skip the next step
			if (LLL_Compartment=="Cytoplasm")
				{
				rename("delimiter"); 
				roiManager("Select", ROI);
			 	run("Make Band...", "band="+max_distance-1);// band_width-1);
				run("Create Mask"); rename("compartmentmask"); 
				imageCalculator("AND create",  "compartmentmask","delimiter"); 
				rename("compartment");
				for(erode=0; erode< erosion_count; erode++) run("Erode"); //for band, this erodes the shape to separate from the nucleus
					//  note this also erodes from outside in both cases so if we really need the max distance, add the erode value to it*** - > add to documentation
					// note#2 this is not applied to "Soma" compartment, so Soma can never require removal of objects from the nuc list like band loss can
	    		selectWindow("compartmentmask"); close();
	    		selectWindow("delimiter"); close();//working on this next
				}	
			 	
						
			run("Create Selection"); // all discontinuous fragments if any are incuded within ROI
			roiManager("Update");//roiManager("Add");
			selectWindow("compartment"); close();		 
			}
		selectWindow("delimiter_masks"); close();
			/*print(roiManager("count"));
				//remove the nulcei from roiManager now that we have the bands 
			seeds=Array.getSequence(Initial_seed_count);
				print("initial count " + Initial_seed_count);
			//Array.print(seeds);
				roiManager("Select", seeds);
			//	roiManager("Delete");
		print(roiManager("count"));
	*/
		setForegroundColor(initial_colour);
		}
	
	
	
	// function to constrain ROIs to areas of intensity matching a threshold			
	// assumes ROI list and copy of image for thresholding	(should be bsubbed and smoothed a bit)
	
	
	
	
	function blackOutsideAllROI()
		{
			// function to black out all area
			// join all ROIs together
			roiManager("deselect");	
			roiManager("Combine"); // this command causes problems where there are overlaps..
			//roiManager("Add"); not needed
			blackOutsideOneROI();
		}
	
	
	// 1. black out area outside ROIs on the image - not needed?
	function blackOutside()
		{
		// function to black out all area
		// join all ROIs together
		roiManager("deselect");	
		roiManager("Combine"); // this command causes problems where there are overlaps..
		//roiManager("Add"); not needed
		//select all area outside ROIs
		run("Make Inverse");
		// add this as a new ROI
		roiManager("Add");
		//print(roiManager("count"));
		// black out the image area outside the ROIs
		temp = getValue("rgb.foreground");
	//print(getValue("rgb.foreground"));
		setForegroundColor(0,0,0);
		roiManager("select", roiManager("count")-1);
		roiManager("Fill");//sho
		setForegroundColor(temp);
		// remove this outside-ROI ROI
		roiManager("select", roiManager("count")-1); 
		roiManager("delete");
		}
	
	
	//ThresholdROIs(20, 2550);
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
	//print(ROIcount, ROInumber,x,y,w,h,minThreshold, maxThreshold);
				run("Duplicate...", "title=temp");
				blackOutsideOneROI(); // remove nearby material outside, this deselects the ROI
				roiManager("select", ROInumber);
				setThreshold(0, minThreshold); //the range to discard - might be best to use a smoothed image here? consider bckgd
	//setThreshold(0, 20);
				run("Create Selection"); // requires 8bit
	//print(selectionType(),  getValue("Mean"));
				if ((selectionType() != -1) && getValue("Mean")!=0) //check it even exists and later again after thresholding      
					{
					run("Set...", "value=0");			
					//run("Restore Selection"); no
					setThreshold(minThreshold+1, maxThreshold); //the
	//setThreshold(020, 3550);
					run("Make Inverse");
					if (selectionType() != -1) 
						{
						getSelectionBounds(x1, y1, w1, h1);
	//print(x1,y1,w1,h1); x=1670;y=722;getSelectionBounds(x, y, w, h);print(x,y,w,h);
					setSelectionLocation(x+x1, y+y1); //if selection loses pixels the position will have shifted
					roiManager("update"); 	// not roiManager("add");
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
			//print("Checked ROI#"+ROInumber+"; "+roiManager("count")+" ROIs remaining", x,y,w,h,minThreshold, maxThreshold);		
			}
		nucROIsToRemove=Array.deleteValue(nucROIsToRemove, -1);	// remove the -1 from the list as they were just fillers
		return 	nucROIsToRemove;
		}	
	
	function blackOutsideOneROI()
		{
		run("Make Inverse");
		// add this as a new ROI
		roiManager("Add");
		//print(roiManager("count"));
		// black out the image area outside the ROIs
		temp = getValue("rgb.foreground");
	//print(getValue("rgb.foreground"));
		setForegroundColor(0,0,0);
		roiManager("select", roiManager("count")-1);
		roiManager("Fill");//sho
		setForegroundColor(temp);
		// remove this outside-ROI ROI
		roiManager("select", roiManager("count")-1); 
		roiManager("delete");
		}
	
	} //end of function  GenerateCytoBandsFromNucSeeds  with 3 internal functions


function Bands_without_overlap_old(template_image, band_width, erosion_count)
	// this takes a ROImanager list of seeds (nuclei) and expands them all in a non-overlapping way
	//N.B. if initial seeds overlap, there will be trouble! Seems to be OK if they are just touching
	//ROImanager ends up with the band ROIs
	{
	
	 initial_colour = getValue("color.foreground");
	 setForegroundColor(255, 255, 255);//ensure fill generates an objective
	 selectWindow(template_image);//create new image of correct size to work with masks
	 getDimensions(width, height, channels, slices, frames);
	 newImage("Seeds", "16-bit black", width, height, 1);
	//show all ROIs and burn them into the seeds image
	run("Select All");
	roiManager("Fill");//show all ROIs listed as white
	setOption("BlackBackground", true);
	run("Make Binary");
	run("Invert"); //black on white background
	run("Distance Map");//creates graident of grey levels according to distance
	setAutoThreshold("Default dark");
	// this defines how far out the delimiter should go. In attovision it is masked against a second channel - we could consider this
	setThreshold(band_width+1, 255);  //sets areas further from seeds as thresholded (red), added 1 to match the band_width use later

	
	run("Convert to Mask");//thresholded area to white, expanded seeds in black
	run("Invert");// now expanded seeds in white
	run("Watershed");
	rename("delimiter_masks");
	
	//loop through nucleus ROIs
	Initial_seed_count=roiManager("count"); //the count will increase ...
	for(ROI=0; ROI<Initial_seed_count; ROI++)
		{
			
		selectWindow("delimiter_masks");
		roiManager("Select", ROI);
		//roiManager("Select", 1);
		Roi.getBounds(x, y, width, height)
		doWand(x,y);
		run("Create Mask"); rename("delimiter"); //new image showing max non-overlapping bounds of current ROI
		roiManager("Select", ROI);
	 	run("Make Band...", "band="+band_width-1);
		run("Create Mask"); rename("bandmask"); 
		imageCalculator("AND", "bandmask","delimiter"); 
		selectWindow("bandmask"); 
		for(erode=0; erode< erosion_count; erode++) run("Erode"); //erode the shape to separate from the nucleus
		//  note this also erodes from outside so if we really need the max distance, add the erode value to it

		run("Analyze Particles...", "size=1-Infinity add composite"); // add the shape to the ROI manager. Is the min size appropriate?
		//"//Enable the particle analyzer’s “Composite ROIs” option in the latest daily build (1.53g35) and particles with holes will be handled as expected. https://forum.image.sc/t/analyze-particles-to-include-in-hole-particles/21916/11"
		 selectWindow("delimiter"); close();
		 selectWindow("bandmask"); close();
		}
	selectWindow("delimiter_masks"); close();
	//remove the nulcei now that we have the bands
	roiManager("Select", newArray(0,Initial_seed_count-1));
	roiManager("Delete");
	
	setForegroupdColor = initial_colour;
	}






function killROImanager()
{
if (roiManager("Count")!=0) {roiManager("Select All"); roiManager("Delete"); }
if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");} //without delete ROI manager gets longer every time!
}



function getSignalNames(L_SignalNamesRGBgroups, L_Channels, LL_Group) 
	{ 
	firstchannel = Channels * (L_Group -1); 
	lastchannel = Channels * (L_Group);
	return Array.slice(L_SignalNamesRGBgroups, firstchannel, lastchannel); // 3,6 or 0, 3
	}




function ThresholdandCalcSignals(L_SegmentationChannel, L_CalciumChannel, L_RatioPairs, L_path,
 L_SegmentationFolder, L_OutputFolderKernel, L_well, L_Group, L_SignalNamesRGB, L_TWindow, L_BaselineReads,
 reportstarted, L_CollectDataReportFile, L_ThresholdArray, L_ThresholdCode)
{
	//Uses ThresholdArray - this is ThresholdCode with separators, so it is needed unlike thresholdcode 
	//SignalNamesRGBgroups not needed, L_Group  is only used for report and as Group defines content of RGBSignalNames

	// TO DO :: this function uses results tables to convert data in images to csv
	L_channels=L_SignalNamesRGB.length;


	if(L_TWindow!="") WindowCorrectedSegmentationPath=L_path + L_SegmentationFolder + File.separator+L_TWindow; // saved data is in common place for all windows with flag L_TWindow, if it is "" then there is no Window flag in the saved data as it is not needed
	else WindowCorrectedSegmentationPath=L_path + L_SegmentationFolder;


	NonSegmentationImages =newArray(L_SignalNamesRGB.length-1);
	k=0;
	for(i=0; i<L_SignalNamesRGB.length;i++) if(i!=L_SegmentationChannel-1)  	{NonSegmentationImages[k]=L_SignalNamesRGB[i];   k++; }
		

	// below controlled by L_Group, but it has not been tested for many versions
	
	//threshold code is how the thresholds are indicated in the filename, probably need a metadata store instead or foldername
	OutputFolder = L_OutputFolderKernel+L_ThresholdCode; 	//save results in subdirectory
	OutputL_path=L_path+ OutputFolder + File.separator;
	if (!File.exists(OutputL_path)) File.makeDirectory(OutputL_path); 
	outpathkernel=OutputL_path + "Results"+L_TWindow+L_well;

	// take shape to a tiff for cells meeteing threshold - run("Set Measurements...", "area mean standard modal min centroid center perimeter fit shape feret's median skewness kurtosis redirect=None decimal=3");
	// saveAs("Results", SavePath + "Results"+well+"ROI-SpatialFeaturesFromCaMAXproj"+".xls"); //saving compartment  data output

	for (i = 0; i<L_channels; i++) //check for nuc only as the segmentation channel may have  no cyt -  updates may  change this?
	{
	tablename="Results"+L_well+L_SignalNamesRGB[i]+compartment[0] +".xls";
	filetoopen = WindowCorrectedSegmentationPath +File.separator +tablename; //deal with double separator
	if (File.exists(filetoopen) != 1) {
		if (Verbosity >1) {print(filetoopen + " does not exist. Will try next well."); print("");}
		; return false ; // indicates well is aborted
		} // skip to next L_well
	}



	//wells do exist, write report
	//ChannelsForThresholdingOfAverages="Channels for Thresholding of averages ="+ NonSegmentationImages[0];
	//for(k=1;k<NonSegmentationImages.length;k++)  ChannelsForThresholdingOfAverages = ChannelsForThresholdingOfAverages + ", "+ NonSegmentationImages[k];
	//ChannelsForThresholdingOfAverages = ChannelsForThresholdingOfAverages+ "\r\n";
	ChannelString=" "; //AbsMinThresholdString=" ";AbsMaxThresholdString=" ";AvgMinThresholdString=" ";AvgMaxThresholdString=" ";
	for (i=0;i<L_channels; i++) ChannelString = ChannelString + L_SignalNamesRGB[i] + ",";


	// These are used in report and in thresholding
	ThresholdTypes = newArray("Average", "Min", "Max"); // used to define z project, so these names have to stay as is
	AbsMinThreshold= Array.slice(L_ThresholdArray, 0*L_channels, L_channels); 
	AbsMaxThreshold= Array.slice(L_ThresholdArray, 1*L_channels, 2*L_channels); 
	AvgMinThreshold= Array.slice(L_ThresholdArray, 2*L_channels, 3*L_channels); 
	AvgMaxThreshold= Array.slice(L_ThresholdArray, 3*L_channels, 4*L_channels); 
	ThresholdStringForReport = getThresholdReportString(AbsMinThreshold, AbsMaxThreshold, AvgMinThreshold,AvgMaxThreshold, L_channels);
	
	function getThresholdReportString(L_AbsMinThreshold, L_AbsMaxThreshold, L_AvgMinThreshold,
	L_AvgMaxThreshold, LL_channels)
	{
	AbsMinThresholdString=" ";AbsMaxThresholdString=" ";AvgMinThresholdString=" ";AvgMaxThresholdString=" ";
		for (i=0;i<LL_channels; i++) {AbsMinThresholdString = AbsMinThresholdString+ toString(L_AbsMinThreshold[i]) + ",";}
		for (i=0;i<LL_channels; i++) {AbsMaxThresholdString = AbsMaxThresholdString+  toString(L_AbsMaxThreshold[i]) + ",";}
		for (i=0;i<LL_channels; i++) AvgMinThresholdString = AvgMinThresholdString+  toString(L_AvgMinThreshold[i]) + ",";	
		for (i=0;i<LL_channels; i++) AvgMaxThresholdString = AvgMaxThresholdString+  toString(L_AvgMaxThreshold[i]) + ",";
	ThresholdReportString ="Absolute Minimum Thresold="+AbsMinThresholdString+ "\r\n"+ 
							"Absolute Maximum Thresold="+AbsMaxThresholdString+ "\r\n"+
							"Average Minimum Thresold="+AvgMinThresholdString+ "\r\n"+
							"Average Maximum Thresold="+AvgMaxThresholdString+ "\r\n";
	return ThresholdReportString;
	}

		
	//Generate Report
	//reportfile=OutputL_path+"DataCollection"+DateStampstring()+".txt";   //Merged files will overwrite so there's no point making a unique ID

	if (!reportstarted) 
		{
		File.saveString("Collecting Data - starting/version "+VersionNumber+ " using IJ version " + IJVersionRunning + "\r\n"+ "\r\n",L_CollectDataReportFile);
		//reportstarted= true; this will be updated by caller
		}
	else { File.append("\r\n",L_CollectDataReportFile); 	}

	File.append("Time Window="+L_TWindow+ "\r\n", L_CollectDataReportFile);
	File.append("Well="+L_well+ "\r\n", L_CollectDataReportFile);
	File.append("source path="+L_path+ WindowCorrectedSegmentationPath+ "\r\n", L_CollectDataReportFile);
	File.append("Group="+L_Group+ "\r\n", L_CollectDataReportFile);
	File.append("NumberofBaselineReads="+L_BaselineReads+ "\r\n", L_CollectDataReportFile);
	File.append("Channels="+ChannelString+ "\r\n", L_CollectDataReportFile);
	File.append(ThresholdStringForReport, L_CollectDataReportFile);
	//end report

	

	//now the Shape features
	ShapeFeaturesExist=true;//default
	tablename= "Results"+L_well+"ROI-SpatialFeaturesFromCaMAXproj"+".xls";
	filetoopen=WindowCorrectedSegmentationPath +File.separator +tablename; //saving compartment  data output
	if (File.exists(filetoopen) != 1) ShapeFeaturesExist=false;


	print(printformatter + "Collecting data from well " + CurrentWell + " at "+ WindowCorrectedSegmentationPath);
	L_numtimepoints = newArray(L_channels);



	for (i=0; i<L_channels; i++) 
		{ //for KTR L_SignalNamesRGB there are two compartments
			for (j=0; j<2; j++) 
				{
				ExtractIvTmean_v2(L_path+ L_SegmentationFolder + File.separator, L_well, L_SignalNamesRGB[i],compartment[j], L_TWindow); //returns e.g. ERKnuc and ERKnucT
				}	
			selectWindow(L_SignalNamesRGB[i]+compartment[0]+"T"); //getDimensions(width, height, channels, slices, frames); 	
			numL_cells = getHeight(); //height;
			L_numtimepoints[i]= getWidth(); //width; // get the numL_cells and numTPs from each since the calcium one is [2] and has more TP
		}
		//Above loop creates JNKnuc, JNKband, ERKnuc, ERKband, JNKnucT, JNKbandT, ERKnucT, ERKbandT and same for Ca now
		
	if(L_CalciumChannel!=-1)//last line does the Ca if it exists - only for nuclear region for now WARNING!!!!!!!!!!!
		{
		ExtractIvTmean_v2(L_path +L_SegmentationFolder + File.separator, L_well, L_SignalNamesRGB[L_CalciumChannel-1],"big"+compartment[0], L_TWindow); selectWindow(L_SignalNamesRGB[L_CalciumChannel-1]+"big"+compartment[0]); close(); //only need the "T" transposed version; nuc for ca, and dont need the depth version //creates uneroded CabignucT, Cabignuc not CanucT, Canuc because this ROI is not eroded
		ExtractIvTmean_v2(L_path +L_SegmentationFolder + File.separator, L_well, "Condensed"+L_SignalNamesRGB[L_CalciumChannel-1],compartment[0], L_TWindow); selectWindow("Condensed"+L_SignalNamesRGB[L_CalciumChannel-1]+compartment[0]+"T"); close(); // only need the untransposed verson; use the condensed calcium for thresholding becayse fast calcium alignment can fail using nanoJ in version 5d29j
		}
		
	//ExtractIvTmean flashes on the screen, v2 reads text direct to img with a temp file, no Results table or flashing


		
	if(ShapeFeaturesExist) 
		{
		tablename =  "Results"+L_well+"ROI-SpatialFeaturesFromCaMAXproj"+".xls";
		if(L_TWindow!="") 	L_file=L_path +L_SegmentationFolder + File.separator+L_TWindow+File.separator+tablename; 
		else L_file=L_path +L_SegmentationFolder + File.separator + tablename; 

			txtImg= replace(File.openAsString(L_file), "\t", ","); //xls file full of tabs, looks like we need commas for run("Text Image..."
			txtImg=substring(txtImg, indexOf(txtImg, "\n")+1); //remove first line which is a header
		if (File.exists(L_file+"temp.csv")) a=File.delete(L_file+"temp.csv"); //if there is an old one, delete AND make sure it is gone 
		do {wait(2);} while(File.exists(L_file+"temp.csv")); 

		File.saveString(txtImg, L_file+"temp.csv");
		//open it once it is available
		do {wait(2);} while(!File.exists(L_file+"temp.csv"));
		run("Text Image... ", "open=["+L_file+"temp.csv]"); 
			//remove the 1st (rowname) column
			getDimensions(width, height, tempchannels, slices, frames); // don't overwrite L_channels
			makeRectangle(1, 0, width, height);	
			run("Crop");

		rename("ShapeFeatures");
		 //because IvT fn was good for the others (it skips 2/3 of columns) but not for this one, the cells are vertical in xls not horizontal and all values needed
		numFeatures= getWidth();
		newImage("ShapeFeatures"+ "Thresholded", "32-bit black", numFeatures, numL_cells, 1); //create container for Ca data L_passing threshold 
		//NormalisedThreshold object will be generated from this after completion of Thresholding
	 }
	 
	//generate images to identify min, max and average values for each channel for all L_cells
	//N.B. Do not apply threshold on L_SegmentationChannel band from testing here because band should be zero and not appropriate for thresholding! But still generate it for simplicity
	//for (j=0;j<2;j++) {selectWindow(L_SignalNamesRGB[L_SegmentationChannel-1]+compartment[j]); close();} 

	// this section generates a stack of all values all compartments for each channel to apply thresholding
	
	for (i=0; i<L_channels; i++) 
		{
		if (i==L_CalciumChannel-1)  // this means Canucvalues will not exist, don't tru to close it
			{ // N.B. - here we will not threshold on cyto Ca even if reporter may in some cases be not constrained to nucleus
			// this is a workaround for nanoJ alignment failure: risk that fastCa not aligned but condensed data in merge is OK -> threshold the condensed version only
			selectWindow("Condensed" +L_SignalNamesRGB[i]+ compartment[0]); 
			run("Duplicate...", "title="+L_SignalNamesRGB[i] + "values"+" duplicate");  // note here we lose the "Condensed" as thresholding can be applied systematically
			selectWindow("Condensed" +L_SignalNamesRGB[i] + compartment[0]); close();
			}
		else
			{
			if((i==L_SegmentationChannel-1)&& i!=L_CalciumChannel-1)//the segmentation channel should only have a nuclear compartment, exclude the band compartment for thresholding!
				{
				 selectWindow(L_SignalNamesRGB[i]+compartment[0]); 
				run("Duplicate...", "title="+L_SignalNamesRGB[i] + "values"+" duplicate");
				} //run("Concatenate...", "  title=["+L_SignalNamesRGB[i] + "values] keep image1="+L_SignalNamesRGB[i][i]+compartment[0]+" image2="+L_SignalNamesRGB[i][i]+compartment[1]+" image3=[-- None --]");
			else //"normal" channels
				{
				run("Concatenate...", "  title=["+L_SignalNamesRGB[i] + "values] keep image1="+L_SignalNamesRGB[i]+compartment[0]+" image2="+L_SignalNamesRGB[i]+compartment[1]+" image3=[-- None --]");				
				}
			}	
		
		// close all compartment images including the calcium one that was not actually used in the present script 	
		for (j=0;j<2;j++) {selectWindow(L_SignalNamesRGB[i]+compartment[j]); close();} //closes ALL nuc/band compartment images now and we only have [Channel]values //- ERKnuc, JNKnuc, ERKband, JNKband; now we have ErkValues, JNKValues	
		
		
		if (nSlices!=1) //catch error when there happens to be only a single plane in the experiment 
			{
			//selectWindow(L_SignalNamesRGB[i] + "values");
			//print(nSlices);
			
			for (j=0; j< lengthOf(ThresholdTypes); j++) // use the ThresholdTypes string array
				{
				selectWindow(L_SignalNamesRGB[i] + "values");
				run("Z Project...", "projection=["+ThresholdTypes[j]+" Intensity]"); 
				rename(L_SignalNamesRGB[i]+ThresholdTypes[j]);
				}
			/*selectWindow(L_SignalNamesRGB[i] + "values");
			run("Z Project...", "projection=[Min Intensity]"); rename(L_SignalNamesRGB[i]+"Min");
			selectWindow(L_SignalNamesRGB[i] + "values");
			run("Z Project...", "projection=[Max Intensity]"); rename(L_SignalNamesRGB[i]+"Max");*/
			}
		else
			{
			selectWindow(L_SignalNamesRGB[i] + "values");	
			for (j=0;j<lengthOf(ThresholdTypes);j++)
				{
				run("Select All"); 
				run("Duplicate...", "title="+L_SignalNamesRGB[i]+ThresholdTypes[j]+" duplicate");
				}
			/*run("Select All"); run("Duplicate...", "title="+L_SignalNamesRGB[i]+"Avg"+" duplicate"); 
			run("Select All"); run("Duplicate...", "title="+L_SignalNamesRGB[i]+"Min"+" duplicate"); 
			run("Select All"); run("Duplicate...", "title="+L_SignalNamesRGB[i]+"Max"+" duplicate"); */
			}	
		selectWindow(L_SignalNamesRGB[i] + "values"); close();	
		}

	if (Verbosity >2) print("created Avg windows");
	if (Verbosity >2) print("created Min and Max windows");


	for (i=0; i<L_channels; i++) // Generate cyt nuc ratios for ALL channels - i) for KTR ratios and ii) include Ca as QC if NLS, but calculate the other ratio images now to copy them to new images
		{
		imageCalculator("Divide create 32-bit", L_SignalNamesRGB[i]+compartment[1]+"T",L_SignalNamesRGB[i]+compartment[0]+"T"); // generate cyt/nuc ratio image and //band by nuc for each signal
		rename(L_SignalNamesRGB[i]+"AllCells");	//THIS MEANS RATIOS!
		newImage(L_SignalNamesRGB[i]+ "Thresholded", "32-bit black", L_numtimepoints[i], numL_cells, 1); //create containers for data L_passing threshold // no data but height cannot be zero - > will crop off at end!
		}



		
	//***************************************************************************************** 	


	//keep Calcium  channel to save cyt and nuc separately later - no I want all channels saved now!
	for (i=0; i<L_channels; i++)//these are shorter than the calcium ones if there are many more calcium timepoints
		{
		if(i!=L_CalciumChannel-1) {for (j=0;j<2;j++) newImage(L_SignalNamesRGB[i]+ compartment[j]+"Thresholded", "32-bit black", L_numtimepoints[i], numL_cells, 1);}//create containers for data L_passing threshold // no data but height cannot be zero - > will crop off at end!
		}
	//***************************************************************************************** 



	//operation on Ca  channel i.e. channel with more datapoints, if (CaChannelNumber!=-1)
	if (L_CalciumChannel!=-1)
	{
	 for (j=0; j <2; j++) 
		{
		newImage(L_SignalNamesRGB[L_CalciumChannel-1]+ compartment[j]+ "Thresholded", "32-bit black", L_numtimepoints[L_CalciumChannel-1], numL_cells, 1); 
		}//create containers for Ca compartment data passing threshold // no data but height cannot be zero - > will crop off at end!
		selectWindow(L_SignalNamesRGB[L_CalciumChannel-1]+"big"+compartment[0]+"T"); rename(L_SignalNamesRGB[L_CalciumChannel-1]+"bigAllCells"); //print(signal[2] +"AllCells");
		newImage(L_SignalNamesRGB[L_CalciumChannel-1]+ "bigThresholded", "32-bit black", L_numtimepoints[L_CalciumChannel-1], numL_cells, 1); //create container for Ca data L_passing threshold 
	}
		



	// THRESHOLDING 
	// here the cells (datalines on image) are thresholded (not copied over) one by one, it's a bit slow
	L_cellspastthreshold = 0;
	setPasteMode("Copy");
	CellThresoldStatus= newArray(numL_cells);
	
	if (Verbosity >2) // report the thresholding constraints in case there is some unexpected issue
		{
		print("thresholds imposed for channels ", String.join(L_SignalNamesRGB, "-"));
		print("AbsMinThreshold ",String.join(AbsMinThreshold, "-"));
		print("AbsMaxThreshold ",String.join(AbsMaxThreshold, "-"));
		print("AvgMinThreshold ",String.join(AvgMinThreshold, "-"));
		print("AvgMaxThreshold ",String.join(AvgMaxThreshold, "-"));
		}
	
	// threshold each cell
	for (L_cell = 0; L_cell<numL_cells; L_cell++) //WARNING only checking limits of channels 0, 1, Ca
		{ // long loop - don't put anything slow in here
		L_checkvalue=newArray(L_channels*3); //reinitialise
		//note same thresholding projection applied to all three channels
		//threshold images are called L_ThresholdingImages[j]+"Average"|j=0-1 , L_ThresholdingImages[2]+"Min", L_ThresholdingImages[2]+"Max"
		
		//pick up values frommin and max values o  segmentation channel ? no, of all channels!
		for(i=0;i<L_channels;i++)  //found bug here L_channels-1 - since when??
			{
			for(j=0; j<3; j++)
				{
					selectWindow(L_SignalNamesRGB[i]+ThresholdTypes[j]); 
					L_checkvalue[i+j*L_channels] = getPixel(L_cell,0); 
					//debug print("readings for " + L_SignalNamesRGB[i]+ThresholdTypes[j] + " is " + L_checkvalue[i+j*L_channels]);
				}	
			}
		AbsMinPass=1; AbsMaxPass=1; AvgMinPass=1; AvgMaxPass=1;
		// DEBUG firstchanneltofail=-1;
		// DEBUG - this seems to fail for the calcium channel
		for(i=0;i<L_channels-1;i++) 
			{
			AbsMinPass *= (L_checkvalue[i]>=AbsMinThreshold[i]);
			AbsMaxPass *= (L_checkvalue[i+1*L_channels]<=AbsMaxThreshold[i]);
			AvgMinPass *= (L_checkvalue[i+2*L_channels]>=AvgMinThreshold[i]);
			AvgMaxPass *= (L_checkvalue[i+2*L_channels]<=AvgMaxThreshold[i]);
			//DEBUG if((AbsMinPass * AbsMaxPass* AvgMinPass* AvgMaxPass==0)&& firstchanneltofail==-1) firstchanneltofail= i;
			}
		L_pass = AbsMinPass * AbsMaxPass* AvgMinPass* AvgMaxPass;
		

		if (Verbosity >2) 
			{
				print("L_pass threshold outcomes",AbsMinPass, AbsMaxPass, AvgMinPass, AvgMaxPass, "decision "+ (L_pass==1), String.join(L_checkvalue,";")); 
				Array.print(L_checkvalue);
				}
	
		if (L_pass) //copy over data for all  channels, otherwise it is ignored
				{
				CellThresoldStatus[L_cell]=1;
				for (i=0; i<L_channels; i++) // cyt nuc ratios, now include compartment-specific calcium ratio
					{
					 selectWindow(L_SignalNamesRGB[i]+"AllCells");
					 makeRectangle(0, L_cell, L_numtimepoints[i], 1);
					 run("Copy");
					 selectWindow(L_SignalNamesRGB[i]+ "Thresholded");
					 makeRectangle(0, L_cellspastthreshold, L_numtimepoints[i], 1);
					 run("Paste");
					 for (j=0;j<2;j++)
						{// this is for calcium data from compartments - is it always needed when reporter in nuc? Maybe as QC not yet implemented?
						//step 1 - collect the thresholded cells once per loop
						selectWindow(L_SignalNamesRGB[i]+compartment[j]+"T"); 
						makeRectangle(0, L_cell, L_numtimepoints[i], 1);//longer for Calcium usually
						run("Copy");
						selectWindow(L_SignalNamesRGB[i]+ compartment[j]+ "Thresholded");
						makeRectangle(0, L_cellspastthreshold, L_numtimepoints[i], 1);
						run("Paste");
						}		 
					 }
				
				//CALCIUM-SPECIFIC SECTION HERE*****************************************	 
				if (L_CalciumChannel!=-1) //this section is specifically for calcium or related channel that likely has  more timepoints
					{				
					//next  part - use the trimmed ROI data called bignuc because it is a larger version of the nuc ROIs
					//now for calcium "bignuc" we need to normalise due to variable L_cell thickness		
					//note we use median from "baselinetimepoints" to normalise
					//first get non-normalised data;  baseline to determine L_normaliser outside the loop
					selectWindow(L_SignalNamesRGB[L_CalciumChannel-1]+"bigAllCells");
					makeRectangle(0, L_cell, L_numtimepoints[L_CalciumChannel-1], 1);
					run("Copy");
					selectWindow(L_SignalNamesRGB[L_CalciumChannel-1]+ "bigThresholded");
					makeRectangle(0, L_cellspastthreshold, L_numtimepoints[L_CalciumChannel-1], 1);
					run("Paste");		
					//CALCIUM-SPECIFIC SECTION ENDS HERE
					}
					//Shape section begins here
				if(ShapeFeaturesExist) 
					{//for Features, normalistaion is across all cells not across features, so this has to be done outside this cell-by-cell loop
					selectWindow("ShapeFeatures");
					makeRectangle(0, L_cell, numFeatures, 1);
					run("Copy");
					selectWindow("ShapeFeatures"+ "Thresholded");
					makeRectangle(0, L_cellspastthreshold, numFeatures, 1);
					run("Paste");
					} // Shape section ends here
				L_cellspastthreshold ++;
				} //end if cell passed 
			else CellThresoldStatus[L_cell]=0;	//  current cell did not pass
			} //next cell
	
	// close cell-wise thresholding data	
		for(i=0;i<L_channels;i++) 
			{for(j=0; j<lengthOf(ThresholdTypes); j++)	{selectWindow( L_SignalNamesRGB[i]+ThresholdTypes[j] ); close(); }	}
		//for(i=0;i<L_channels;i++) { CloseSelectWindows(newArray(L_SignalNamesRGB[i]+"Avg",L_SignalNamesRGB[i]+"Min", L_SignalNamesRGB[i]+"Max" ));				
	//allcell and thresholded cell traces generated for all channels
	//print(L_SignalNamesRGB[NumeratorChannel]+compartment[j]+ "Thresholded", L_SignalNamesRGB[DenominatorChannel]+compartment[j]+ "Thresholded");
	
	//Array.print(compartment);//setBatchMode("exit and display");
	//L_cellspastthreshold started at 0 so at the end of the loop it equals the total cells past threshold
	//all collected data - currently open as cell by time images - should be cropped down to size and normalised
	//normalise Features - //bycell uses max min for x-min/(max-min) full normalisation. Bug - "-min" works in tests but not in macro - why not?
print("creating ShapeFeaturesNormalisedThresholded");
	if((ShapeFeaturesExist)*(L_cellspastthreshold !=0)) 
		{
		selectWindow("ShapeFeaturesThresholded"); 	run("Canvas Size...", "width="+numFeatures+" height="+L_cellspastthreshold+" position=Top-Center zero");
		generateNormalisedImage("bycell", "ShapeFeaturesThresholded", "ShapeFeaturesNormalisedThresholded", numFeatures, L_cellspastthreshold, 0); //usage bycell|byvalue, imagenameprefix, imagenamepostfix, width, height, special-parameter -> seeks prevfix+postfix, outputs prefix+Normalised
		}
print("done creating ShapeFeaturesNormalisedThresholded");
	// cleanup non-calcium and calcium channels 
	for (i=0; i<L_channels;i++) {for(j=0; j<2; j++) {selectWindow(L_SignalNamesRGB[i]+compartment[j]+"T"); close();}}
	if (Verbosity >2) print(L_cellspastthreshold + " L_cells past threshold");
	if (Verbosity >1) print(d2s(100* L_cellspastthreshold/numL_cells, 0) + "% of L_cells L_passed threshold "+L_ThresholdCode + " in L_well "+L_well + " of "+L_path);

	//save the data now, generating baseline/normalised data as we go	
	//Now the ratioing section, applied only to thresholded single channel data


	RatioNames=newArray(); // so RatioNames.length =0 can be used later if there are none
	if ((L_cellspastthreshold != 0) && (L_RatioPairs.length >0))
		{
		RatioNames = newArray(2*L_RatioPairs.length); //2 compartments hard-coded here
		for (CurrentRatio=0;CurrentRatio<L_RatioPairs.length; CurrentRatio++)
			{
			CurrentPair=split(L_RatioPairs[CurrentRatio], "v"); //cannot use : or /  because excel converts it to date etc
			NumeratorChannel=parseInt(CurrentPair[0])-1;
			DenominatorChannel=parseInt(CurrentPair[1])-1;
			// first consider special case that NumeratorChannel == L_CalciumChannel 
			if (NumeratorChannel == L_CalciumChannel-1) // in this case we estimate denominator intensity from the 2 compartments and expanded to match the Ca time interval
				{
				// define an array of extra images we'll need to clean up later//assumes 2 compartments
				NewTempImages = newArray("canvas", "AreaOfCompartment0", "AreaOfCompartment1", "AreaBybandSignal", "AreaBynucSignal", "SumSignal", "AreaSum");// keep "AreaNormSignal" and close separately
					
				open(WindowCorrectedSegmentationPath +"/Segmentation"+L_well+".tif");	rename("canvas");
				for (CurrentCompartment=0;CurrentCompartment <compartment.length; CurrentCompartment++)
					{
					roiManager("Open",WindowCorrectedSegmentationPath +"/ROI" + compartment[CurrentCompartment]+L_well+".zip");
					NumberOfROIs = roiManager("count"); //print(NumberOfROIs);
					newImage("AreaOfCompartment"+CurrentCompartment, "32-bit black", 1, L_cellspastthreshold, 1); //make space for cells past threshold only
					//run("Properties...", "channels=1 slices=1 frames=1 pixel_width=1 pixel_height=1 voxel_depth=1.0000000 frame=[1 min]");
					Area=newArray(NumberOfROIs);
					selectWindow("canvas"); // thus area is calibrated in um not pixels. 
					for (ROI=0; ROI <NumberOfROIs; ROI++) {roiManager("Select", ROI);Area[ROI]=getValue("Area");}
					CurrentCell =0;
					selectWindow("AreaOfCompartment"+CurrentCompartment);
					//BUG I have seen NumberOfROIs > CellThresoldStatus.length - when did an extra ROI get added?
					for (ROI=0; ROI < NumberOfROIs; ROI++)  if (CellThresoldStatus[ROI]) {setPixel(0,CurrentCell,Area[ROI]); CurrentCell++;} //faster with 2 loops				
					run("Size...", "width="+ L_numtimepoints[DenominatorChannel]+" interpolation=None"); //   resize width as width*compressionfactor
					killROImanager();
					
					DenominatorData=L_SignalNamesRGB[DenominatorChannel]+compartment[CurrentCompartment]+"Thresholded"; //already open				
					imageCalculator("Multiply create 32-bit", DenominatorData, "AreaOfCompartment"+CurrentCompartment); 
					rename("AreaBy"+compartment[CurrentCompartment]+"Signal"); 			
					}	
					
				//the following assume only two compartments
				imageCalculator("Add create 32-bit", "AreaOfCompartment0","AreaOfCompartment1"); rename("AreaSum");  //assumes only 2 compartments
				imageCalculator("Add create 32-bit", "AreaBynucSignal","AreaBybandSignal"); rename("SumSignal");  //assumes only 2 compartments
				imageCalculator("Divide create 32-bit", "SumSignal","AreaSum"); rename("AreaNormSignal");  //expand output to match calcium
				run("Size...", "width="+ L_numtimepoints[L_CalciumChannel-1]+" interpolation=None"); //   resize width as width*compressionfactor

				// now we have the 2-compartment Denominator estimate for ratioing the fast calcium data
				CloseSelectWindows(NewTempImages); // clean up those extra images
				//algorithm based on nuclear calcium but data for both compartments exist
				for (CurrentCompartment=0;CurrentCompartment <compartment.length; CurrentCompartment++)
					{ //here is the problem the Ca is thresholded, the Ratio is not
					NumeratorData="Ca"+compartment[CurrentCompartment]+ "Thresholded";
					RatioNames[2*CurrentRatio+CurrentCompartment] ="Ratio"+L_SignalNamesRGB[NumeratorChannel]+"by"+L_SignalNamesRGB[DenominatorChannel]+compartment[CurrentCompartment];
					imageCalculator("Divide create 32-bit", NumeratorData,"AreaNormSignal");
					
					infile=RatioNames[2*CurrentRatio+CurrentCompartment]+"Thresholded";
					rename(infile); 
					outfile= RatioNames[2*CurrentRatio+CurrentCompartment]+"ThresholdedCells"; 
					Normoutfile =RatioNames[2*CurrentRatio+CurrentCompartment]+"NormalisedThresholdedCells"; 
					condensedoutfile=RatioNames[2*CurrentRatio+CurrentCompartment]+"CondensedNormalisedThresholdedCells";		
					saveCellbyTimeFileset(infile, outfile, Normoutfile, condensedoutfile, CondenseFactor, outpathkernel, L_numtimepoints[NumeratorChannel], L_cellspastthreshold, getNormalisationMethod(NumeratorChannel, L_CalciumChannel), L_BaselineReads);
					}
				selectWindow("AreaNormSignal");close();
				}
			else
				{
				for (CurrentCompartment=0;CurrentCompartment<2;CurrentCompartment++)
					{
					RatioNames[2*CurrentRatio+CurrentCompartment] ="Ratio"+L_SignalNamesRGB[NumeratorChannel]+"by"+L_SignalNamesRGB[DenominatorChannel]+compartment[CurrentCompartment];
					NumeratorImage=L_SignalNamesRGB[NumeratorChannel]+compartment[CurrentCompartment]+ "Thresholded";
					DemonimatorImage=L_SignalNamesRGB[DenominatorChannel]+compartment[CurrentCompartment]+ "Thresholded";
					imageCalculator("Divide create 32-bit", NumeratorImage,DemonimatorImage);
					
					//saveAs("Tiff", outpathkernel +RatioNames[2*i+j]+".tif"); 	close(); //don't save, need to crop first - there's a function for all this, normalises too
					infile=RatioNames[2*CurrentRatio+CurrentCompartment]+"Thresholded"; 
					rename(infile); 
					outfile= RatioNames[2*CurrentRatio+CurrentCompartment]+"ThresholdedCells";
					Normoutfile =RatioNames[2*CurrentRatio+CurrentCompartment]+"NormalisedThresholdedCells"; 
					condensedoutfile="";
					saveCellbyTimeFileset(infile, outfile, Normoutfile, condensedoutfile, CondenseFactor, outpathkernel, L_numtimepoints[NumeratorChannel], L_cellspastthreshold, getNormalisationMethod(NumeratorChannel, L_CalciumChannel), L_BaselineReads);
					}
				}
			}
		}

	

	for (i=0; i<L_channels; i++) //save and Threshold the cytbynucdata // cyt nuc ratios now also for  calcium
		{
		selectWindow(L_SignalNamesRGB[i]+"AllCells");// print("Saving "+signal[i]+"AllCells" + " as " +L_path + "Results"+L_well +signal[i]+"cytbynucAllCells");
		makeRectangle(0,0,0,0); run("Enhance Contrast", "saturated=0.35"); //clear selections and normalise contrast
		saveAs("Tiff", outpathkernel +L_SignalNamesRGB[i]+"cytbynucAllCells"); close();
		if (L_cellspastthreshold != 0) // crop off lines with no L_cells, this is done in the function
			{ 
			infile=L_SignalNamesRGB[i]+"Thresholded"; 
			outfile= L_SignalNamesRGB[i]+"cytbynucThresholdedCells"; Normoutfile =L_SignalNamesRGB[i]+"cytbynucNormalisedThresholdedCells"; 
			condensedoutfile="";
			saveCellbyTimeFileset(infile, outfile, Normoutfile, condensedoutfile, CondenseFactor, outpathkernel, L_numtimepoints[i], L_cellspastthreshold, getNormalisationMethod(i, L_CalciumChannel), L_BaselineReads);
			//by compartment has different baseline read count for calcium and other channels
			adjustedbaselinereads= L_BaselineReads;
			if(i==L_CalciumChannel) adjustedbaselinereads= L_BaselineReads*CondenseFactor;
			for (j=0;j<2;j++)
				{
				infile=L_SignalNamesRGB[i]+ compartment[j]+ "Thresholded"; outfile=infile+"Cells"; Normoutfile =L_SignalNamesRGB[i]+compartment[j]+ "NormalisedThresholdedCells";condensedoutfile="";
				saveCellbyTimeFileset(infile, outfile, Normoutfile, condensedoutfile, CondenseFactor, outpathkernel, L_numtimepoints[i], L_cellspastthreshold, getNormalisationMethod(i,L_CalciumChannel), adjustedbaselinereads);
				}
			}
		else // close files
			{
			selectWindow(L_SignalNamesRGB[i]+ "Thresholded"); close(); //the other images generated from this were never generated if no cells passed threshold//print("Saving "+signal[i]+ "Thresholded" + " as " +L_path + "Results"+L_well +signal[i]+"cytbynucThresholdedCells");
			for (j=0;j<2;j++) 
				{
				selectWindow(L_SignalNamesRGB[i]+ compartment[j]+ "Thresholded"); close();
				if (L_cellspastthreshold !=0) //if not then there cannot have been a normalisation
					{selectWindow(L_SignalNamesRGB[i]+ compartment[j]+ "NormalisedThresholded"); close();}
				}
			}	
		
	}	

		
	if (L_CalciumChannel!=-1)
		{			
		i=L_CalciumChannel-1;//if(L_SignalNamesRGB[2]=="Ca") no longer assumed
		//now save the "big" calcium data
		selectWindow(L_SignalNamesRGB[i]+"bigAllCells");
		makeRectangle(0,0,0,0); run("Enhance Contrast", "saturated=0.35"); //clear selections and normalise contrast
		saveAs("Tiff", outpathkernel +L_SignalNamesRGB[i]+"AllCells"); close();

		if (L_cellspastthreshold !=0) 
			{
			infile=L_SignalNamesRGB[i]+"bigThresholded"; outfile = L_SignalNamesRGB[i]+"ThresholdedCells"; 
			Normoutfile =L_SignalNamesRGB[i]+"NormalisedThresholdedCells"; 
			condensedoutfile=L_SignalNamesRGB[i]+"CondensedNormalisedThresholdedCells";
			saveCellbyTimeFileset(infile, outfile, Normoutfile, condensedoutfile, CondenseFactor, outpathkernel, L_numtimepoints[i], L_cellspastthreshold, getNormalisationMethod(i, L_CalciumChannel), L_BaselineReads*CondenseFactor);
			}
		else
			{
			if (Verbosity >1) print("No L_cells past threshold value " + L_ThresholdCode + ", no thresholded data to save for L_well "+L_well);
			selectWindow(L_SignalNamesRGB[i]+ "bigThresholded"); close();
			if (L_cellspastthreshold !=0) //if not then there cannot have been a normalisation
					{selectWindow(L_SignalNamesRGB[i]+ "bigNormalisedThresholded"); close();}	
			}
		} //end if thresholded cells for calcium files
	
	//now the shape features
	if(ShapeFeaturesExist)
		{
			selectWindow("ShapeFeatures");
			saveAs("Tiff", outpathkernel +"ShapeFeatures"+"AllCells"); close();
			if (L_cellspastthreshold !=0) 
				{
				selectWindow("ShapeFeatures"+ "Thresholded");saveAs("Tiff", outpathkernel +"ShapeFeatures"+"ThresholdedCells"); close(); //run("Canvas Size...", "width="+numFeatures +" height="+L_cellspastthreshold+" position=Top-Center zero"); //
				selectWindow("ShapeFeatures"+ "NormalisedThresholded"); saveAs("Tiff", outpathkernel +"ShapeFeatures"+"NormalisedThresholdedCells"); close();
				}
			else
				{
				selectWindow("ShapeFeatures"+ "Thresholded"); close(); //if no cells then no Normalised file to close
				}
		}

return true ; //indicates well not aborted
//setBatchMode(false);
}






function getNormalisationMethod(channel, LL_CalciumChannel)	//i.e. for i=2 calcium use the median because average not appropriate for spike data and median not for few datapoints
{
if(channel !=LL_CalciumChannel)
 return "byvalue_baselineaverage"; 
else 
 return "byvalue_baselinemedian";
} 








function ExtractIvTmean(L_currentpath, L_currentwell, L_signal, L_compartment,L_TWindow) 
{
tablename="Results"+L_currentwell+L_signal+L_compartment+".xls";
if(L_TWindow!="")
	{open(L_currentpath +L_TWindow+File.separator+ tablename); }
	else
	{open(L_currentpath + tablename); }
	v=getVersion(); vn=parseFloat(substring(v,lengthOf(v)-5, lengthOf(v)-1)); 	if(vn>1.51) 	Table.rename(tablename, "Results");//v1.52a onwards allows all kinds of table names	
	if (isOpen("Results")) {selectWindow("Results"); setLocation(screenWidth, screenHeight);}
	run("Results to Image"); 
setBatchMode("exit and display");stop;
	rename("temp");
	run("Reslice [/]...", "output=1.000 start=Top avoid");
	
	rename(L_signal+L_compartment);
	run("Reslice [/]...", "output=1.000 start=Top rotate avoid");
	rename(L_signal+L_compartment+"T");
	selectWindow("temp"); close();
	/*selectWindow("temp2"); close();*/
}

function ExtractIvTmean_v2(L_currentpath, L_currentwell, L_signal, L_compartment,L_TWindow)  //do not use results window
{
tablename="Results"+L_currentwell+L_signal+L_compartment+".xls";
if(L_TWindow!="") file=L_currentpath +L_TWindow+File.separator+ tablename; 
else file= L_currentpath + tablename; 
tempfile=L_currentpath+"tempResults.csv";

//print(tablename);

txtImg= replace(File.openAsString(file), "\t", ","); //xls file full of tabs, looks like we need commas for run("Text Image..."
txtImg=substring(txtImg, indexOf(txtImg, "\n")+1); //remove first line which is a header

if (File.exists(tempfile)) a=File.delete(tempfile); //if there is an old one, delete AND make sure it is gone 
do {wait(2);} while(File.exists(tempfile)); 

File.saveString(txtImg,tempfile);
//open it once it is available
do {wait(2);} while(!File.exists(tempfile));

run("Text Image... ", "open=["+tempfile+"]"); 

//remove the 1st (rowname) column
getDimensions(width, height, tempchannels, slices, frames);
makeRectangle(1, 0, width, height);	
run("Crop");

rename("temp");
run("Reslice [/]...", "output=1.000 start=Top avoid");
	
rename(L_signal+L_compartment);
run("Reslice [/]...", "output=1.000 start=Top rotate avoid");
rename(L_signal+L_compartment+"T"); //transposed version created
selectWindow("temp"); close();
a=File.delete(tempfile); //clean up but can continue
}



function generateNormalisedImage(method, inputimage, outputimage, width, height, parameter) 
{//usage methods to normalise across cells for each value, across values for each cell, or simply according to a baseline value
	selectWindow(inputimage);// "ShapeFeaturesThresholded");
	run("Select All");
	if(method=="bycell")
		{
		run("Select All"); run("Reslice [/]...", "output=1.000 start=Top avoid"); 
		fullnormalisation=true; //x-min/(max-min)
		}
	else if(method =="byvalue")
		{
		run("Reslice [/]...", "output=1.000 start=Left rotate avoid");
		fullnormalisation=true; //x-min/(max-min)
		}
	else if(method=="byvalue_baselineaverage")
		{
		projectiontype="[Average Intensity]";//that's the format the function calls for 
		makeRectangle(0, 0, parameter, height);
		run("Duplicate...", "title=temp");; rename("temp");// Duplicate was failing to rename here, causing a crash. Forcing rename solved this. v1.53t
		run("Reslice [/]...", "output=1.000 start=Left rotate avoid"); rename("temp2");
		selectWindow("temp"); close();
		selectWindow("temp2");
		fullnormalisation=false; //x-min/(max-min)
		}
	else if(method=="byvalue_baselinemedian")
		{
		projectiontype="Median";//that's the format the function calls for 
		makeRectangle(0, 0, parameter, height);
		run("Duplicate...", "title=temp"); rename("temp");// Duplicate was failing to rename here, causing a crash. Forcing rename solved this. v1.53t
		run("Reslice [/]...", "output=1.000 start=Left rotate avoid"); rename("temp2");
		selectWindow("temp"); close();
		selectWindow("temp2");
		fullnormalisation=false; //x-min/(max-min)
		}
	else 
		{
		print("ERROR: invald parameter passed: " + method);
		return;
		}
	rename(inputimage+"Reslice");
	if(fullnormalisation)
		{
		if (nSlices!=1)
			{
			run("Z Project...", "projection=[Min Intensity]"); rename(inputimage+"Min");
			selectWindow(inputimage+"Reslice"); run("Z Project...", "projection=[Max Intensity]"); rename(inputimage+"Max"); //selectWindow(inputimage+"Reslice"); close(); - done at end in all cases
			imageCalculator("Subtract create 32-bit", inputimage+"Max",inputimage+"Min"); rename(inputimage+"Denominator"); 
			selectWindow(inputimage+"Min"); run("Size...", "width="+width+" height="+height+" average interpolation=None"); //had Bilinear in v4f
			selectWindow(inputimage+"Denominator"); run("Size...", "width="+width+" height="+height+" average interpolation=None"); //had Bilinear in v4f
			imageCalculator("Subtract create 32-bit", inputimage, inputimage+"Min"); rename("temp");
			imageCalculator("Divide create 32-bit", "temp",inputimage+"Denominator"); rename(outputimage);// "ShapeFeaturesNormalisedThresholded"); 
			CloseSelectWindows(newArray(inputimage+"Max", inputimage+"Min", inputimage+"Denominator", "temp"));
			}
		else //cannot do x-min/max-min when max=min so don't do anything
			{selectWindow(inputimage); run("Select All"); run("Duplicate...", "duplicate"); rename(outputimage);}
		}
	else 
		{
		if (nSlices!=1) {run("Z Project...", "projection="+projectiontype); rename(inputimage+"Normaliser");}//average or median
		else{selectWindow(inputimage+"Reslice"); run("Duplicate...", "duplicate"); rename(inputimage+"Normaliser");	}  //there's only one value, don't need to project
		run("Size...", "width="+width+" height="+height+" average interpolation=None"); //had Bilinear in v4f //now can use the calculator
		imageCalculator("Divide create 32-bit", inputimage,inputimage+"Normaliser"); rename(outputimage);// "ShapeFeaturesNormalisedThresholded"); 
		selectWindow(inputimage+"Normaliser"); close();
		}
	selectWindow(inputimage+"Reslice"); close();
	}

//function cropCellbyTimeFileset(inF, outF, NormoutF, CondensedF, CondenseFac, pathkernel, width, cells, normmethod, basepoints)




function saveCellbyTimeFileset(inF, outF, NormoutF, CondensedF, CondenseFac, pathkernel, width, cells, normmethod, basepoints)
{
    //using an input cell-by-time images, generate output files of data as is, normalised version and, if defined, a compressed version	

    selectWindow(inF); makeRectangle(0,0,0,0); run("Enhance Contrast", "saturated=0.35"); //clear selections and normalise contrast
	run("Canvas Size...", "width="+width+" height="+cells+" position=Top-Center zero"); // removing blank row left by cells excluded by thresholding
	generateNormalisedImage(normmethod, inF, NormoutF, width, cells, basepoints); //usage bycell|byvalue, imagenameprefix, imagenamepostfix, width, height, special-parameter -> seeks prevfix+postfix, outputs prefix+Normalised
	makeRectangle(0,0,0,0); run("Enhance Contrast", "saturated=0.35"); //clear selections and normalise contrast
	saveAs("Tiff", pathkernel +NormoutF);  
	if (CondensedF!="")
		{//also save compressed representation for use with the other signals with corresponding # timepoints
		run("Select All"); run("Size...", "width="+(width/CondenseFac)+" height="+cells+" average interpolation=Bilinear"); //note Fiji requires bracket around divide, IJ1 did not
		saveAs("Tiff", pathkernel +CondensedF);  close();
		}
	else close();		
	selectWindow(inF); 	saveAs("Tiff", pathkernel +outF); close();
	}

	

// this function should run`through all wells, but it stops after a few - why? DEBUG
function AnalyseSpikes(L_Channels, L_CalciumChannel, L_SignalNamesRGBgroups,L_GroupCount, L_experimentpath, L_OutputFolderKernel,  L_WellList, L_TWindow, L_ThresholdCode)
{
setBatchMode(true);

OutputFolder = L_OutputFolderKernel+L_ThresholdCode; //L_SignalNamesRGB dependent
Outputpath=L_experimentpath+ OutputFolder + File.separator;
if(!File.exists(Outputpath)) {print("No folder " + Outpath + " from which to collate data."); return;} //don't interrupt processing of additional wells or experiments



SpikeThreshold= 0.1; // hard coded here
for (WellID =0; WellID <lengthOf(L_WellList); WellID++)  // problem here?
		{
		CurrentWell = L_WellList[WellID]; 
		rowcode = charCodeAt(CurrentWell,0); columncode = substring(CurrentWell,1); //for the old groups below
				
		//for (rowcode=charCodeAt(FirstRow, 0); rowcode<charCodeAt(LastRow, 0)+1;rowcode++) {Row = fromCharCode(rowcode); 
		if (GroupType == "Row")  
			{GroupNumber = 2 - ((rowcode+1) % L_GroupCount);} // that's 2 or 1 no 0 //Note that we assume here that B02 is group 1 so A01 would be group2 - this function probably needs an update
			else 
			{GroupNumber = 1;}
			//for (columncode=FirstColumn; columncode<LastColumn+1;columncode++) {
		if (GroupType == "Column") 
			{GroupNumber = 2- ((columncode+1) % L_GroupCount);}// that's 2 or 1 no 0 	//Note that we assume here that B02 is group 1 so A01 would be group2 	//Note 2 no else, it is set by column or at one already, don't change it!
		
		firstchannel = L_Channels * (GroupNumber -1);	lastchannel = L_Channels * (GroupNumber);
		L_SignalNamesRGB = Array.slice(L_SignalNamesRGBgroups, firstchannel, lastchannel); // 3,6 or 0, 3

		L_signal=L_SignalNamesRGB[L_CalciumChannel-1] + "Normalised"; // collect spike data from normalised cells because the selection can be defined as a fraction of spike height (from min, it seems)
		SpikeDataSource= "Results"+L_TWindow+CurrentWell+L_signal+"ThresholdedCells.tif";
		filetoopen = Outputpath + SpikeDataSource;
		if (!File.exists(filetoopen)) 
			{
			if(Verbosity >2) print(filetoopen + " does not exist. Will try next well."); 
			} // skip to next well, don't quit entire collection!
		else {	
			open(filetoopen); 
			NumberOfCells=getHeight();
			NumberTimepoints=getWidth();
			NumberOfTimeunits=NumberTimepoints/CondenseFactor;
			NumberOfSpikesImage= "Results"+L_TWindow+CurrentWell+ L_SignalNamesRGB[L_CalciumChannel-1]+"SpikeRateFrom"+"NormalisedThresholdedCells.tif"; // in this order to be able to find and collate the data later
			AverageSpikeHeightImage="Results"+L_TWindow+CurrentWell+ L_SignalNamesRGB[L_CalciumChannel-1]+ "SpikeHeightFrom"+"NormalisedThresholdedCells.tif";
			
			newImage(NumberOfSpikesImage, "32-bit black",NumberOfTimeunits, NumberOfCells, 1); //make space for cells past threshold only
			newImage(AverageSpikeHeightImage, "32-bit black",NumberOfTimeunits, NumberOfCells, 1); //make space for cells past threshold only
			for (cell=0;cell<NumberOfCells; cell++)
				{
				selectWindow(SpikeDataSource);
				makeRectangle(0,cell,NumberTimepoints, 1); // (timeunit*TimeUnitWidth, cell, (timeunit+1*TimeUnitWidth),1);
				L_profile = getProfile();//run("Plot Profile");	without plotting:-
				
				for (timeunit=0; timeunit<NumberOfTimeunits; timeunit++)
					{
					SumSpikeHeight=0;
					CurrentTimerangeData=Array.slice(L_profile, CondenseFactor*timeunit, CondenseFactor*(timeunit+1));
					SpikeTimes=Array.findMaxima(CurrentTimerangeData, SpikeThreshold, 1) ; //exclude edges
					NumberOfSpikes=parseFloat(SpikeTimes.length);//so that 0 is not NaN				
					selectWindow(NumberOfSpikesImage); setPixel(timeunit, cell, NumberOfSpikes); 
		
					for (spike=0; spike< NumberOfSpikes; spike++) {SumSpikeHeight= SumSpikeHeight+CurrentTimerangeData[SpikeTimes[spike]];}
					if (NumberOfSpikes!=0) AverageSpikeHeight=SumSpikeHeight/NumberOfSpikes; 
					else AverageSpikeHeight =0;
					selectWindow(AverageSpikeHeightImage); setPixel(timeunit, cell, AverageSpikeHeight);		
					} //next timeunit
				} //nextcell
			selectWindow(NumberOfSpikesImage);saveAs("tiff", Outputpath + NumberOfSpikesImage); close();
			selectWindow(AverageSpikeHeightImage);saveAs("tiff", Outputpath + AverageSpikeHeightImage); close();
			selectWindow(SpikeDataSource); close();
			}
		}// next well

print("spike analysis completed for " + L_experimentpath);
setBatchMode(false);
}


		
function SaveAverageTraces(L_parameters_collected_per_channel, L_Channels, L_CalciumChannel,L_SegmentationChannel, L_SignalNamesRGBgroups, L_RatioPairs, L_GroupCount, L_experimentpath, L_OutputFolderKernel, L_WellList,  L_TWindow, L_ThresholdCode) // loops thorough all wells here so group is determined locally.
//Note data from all groups is gathered to a single file because wells are evaluated one by one and folder locations are determined according to format parameters
{
// called outside of well and therefore group loop 
setBatchMode(true);
//set up folder names and check the relevant data folder exists (not whether files  exist, that's another matter)

OutputFolder = L_OutputFolderKernel+L_ThresholdCode; //L_SignalNamesRGB dependent
Outputpath=L_experimentpath+ OutputFolder + File.separator;
if(!File.exists(Outputpath)) {print("No folder " + Outputpath + " from which to collate data."); return;} //don't interrupt processing of additional wells or experiments
				
PercentComplete= 0;
ResultsWindowFlag= false; //no results window showing - don't keep checking it takes time, and can also cause the method to fail altoghether
expandcelltrack = 10;// expand to 10 pixels per cell on the  well by time tiff representations 

if (L_CalciumChannel==-1) L_spikes=false;
	else L_spikes= File.exists(Outputpath+"Results"+L_TWindow+L_WellList[0]+L_SignalNamesRGBgroups[L_CalciumChannel-1] + "SpikeRateFromNormalised" +"ThresholdedCells.tif");    // just checking one well one file to ensure backward compatibility


maxk = L_Channels *L_parameters_collected_per_channel;	 //this includes calcium
if(L_CalciumChannel !=-1) 
	{
	maxk=maxk+2;//5;		calcium could be recorded in detailed and condensed form, hence an extra channel, but still need 2 extras because the uneroded nuclei are used, also for thresholding; it means nuc and band may be divideby0
	maxk=maxk+2*L_spikes;
	}
maxk=maxk+4*L_RatioPairs.length; //2 compartments  with and without normalisation 


CellsPerWell = newArray(L_WellList.length);


for (k = 0; k<maxk; k++)
	{
	PercentComplete= round(100*k/maxk);
	//Use wellcode but keeping the old groups definitions for now
	for (WellID =0; WellID <lengthOf(L_WellList); WellID++) 
		{
		CurrentWell = L_WellList[WellID]; 
		rowcode = charCodeAt(CurrentWell,0); columncode = substring(CurrentWell,1); //for the old groups below
				
		//for (rowcode=charCodeAt(FirstRow, 0); rowcode<charCodeAt(LastRow, 0)+1;rowcode++) {Row = fromCharCode(rowcode); 
		if (GroupType == "Row")  
			{GroupNumber = 2 - ((rowcode+1) % L_GroupCount);} // that's 2 or 1 no 0 //Note that we assume here that B02 is group 1 so A01 would be group2 - this function probably needs an update
			else 
			{GroupNumber = 1;}
			//for (columncode=FirstColumn; columncode<LastColumn+1;columncode++) {
		if (GroupType == "Column") 
			{GroupNumber = 2- ((columncode+1) % L_GroupCount);}// that's 2 or 1 no 0 	//Note that we assume here that B02 is group 1 so A01 would be group2 	//Note 2 no else, it is set by column or at one already, don't change it!
		
		firstchannel = L_Channels * (GroupNumber -1);	lastchannel = L_Channels * (GroupNumber);
		L_SignalNamesRGB = Array.slice(L_SignalNamesRGBgroups, firstchannel, lastchannel); // 3,6 or 0, 3
		
		//these arrays are from Signal Names, depending the group
		ProcessedSignals = getProcessedSignals(maxk, L_Channels, L_CalciumChannel, L_parameters_collected_per_channel, L_RatioPairs, L_spikes);
		ProcessedSignalsPreIndex = getProcessedSignalsPreIndex(maxk, L_Channels, L_CalciumChannel, L_parameters_collected_per_channel, L_RatioPairs, L_spikes);
		ExtendedSignalNames = getExtendedSignalNames(L_SignalNamesRGB, L_RatioPairs); // Remember array is a pointer, so this changes L_SignalNamesRGB

		//This still causes one screenflash per experiment - is that acceptable?
			if(!ResultsWindowFlag) 
				{
				setResult("Null", nResults, "null2"); // if there is no results table the first data ends up on the far left and labels may not show at all - generate an empty results table resolves this
				updateResults; //this generates the results tables but there'll be no row labels without the above
				selectWindow("Results"); setLocation(screenWidth, screenHeight); 
				run("Clear Results"); 
				ResultsWindowFlag= true;//without select, the log window disappears!
				//this hijacks the Log window and it ends up out of sight - alt Space X to recover but not while results are updating...
				}
				
			if(rowcode==charCodeAt(WellList[0], 0) && columncode==substring(WellList[WellList.length-1],1))
				print("Collating " +  ExtendedSignalNames[ProcessedSignalsPreIndex[k]] + ProcessedSignals[k] + " data from wells at "+ L_experimentpath + " : "+PercentComplete+" % complete"); 


			if(L_SignalNamesRGB.length>1) //found some channels
				{
				NonSegmentationImages =newArray(L_SignalNamesRGB.length-1); 
				kk=0;
				 // find and exclude the segmentation channel, count the rest
				for(i=0; i<L_SignalNamesRGB.length;i++) if(i!=L_SegmentationChannel-1) {NonSegmentationImages[kk]=L_SignalNamesRGB[i];  kk++;}
				}
			
				
			currentsignal = ExtendedSignalNames[ProcessedSignalsPreIndex[k]] + ProcessedSignals[k] ;// inclulde the extended names for ratio pairs   L_SignalNamesRGB[ProcessedSignalsPreIndex[k]] + ProcessedSignals[k] ;
			if (Verbosity >1) print(printformatter +"processing signal "+k+" ("+currentsignal+") for well "+CurrentWell); //
			if (Verbosity >2) print(printformatter +"processing "+L_experimentpath + CurrentWell +" channel " + currentsignal); //"\\Update:" +
			if(Verbosity>2) print("Calling CollateThresholdandSignals", Outputpath, CurrentWell, currentsignal, L_TWindow);
			
			CellsPerWell[WellID]=CollateThresholdandSignals(Outputpath, CurrentWell, currentsignal, L_TWindow);
				
		} //} //second one this is for old row and column counter

		
		if (isOpen("Results"))	
			{
			if(getValue("results.count") ==0)		
				{print("WARNING: no results to save for "+currentsignal);}//return 0;}
			else	
				{
				//if there are results, proceed and save the data	
				if (!isOpen("Results"))  {print("WARNING: no results found at" +Outputpath +  L_TWindow+currentsignal);return 0;}
				//could this allow trying the next k?
						
				selectWindow("Results");  setLocation(screenWidth, screenHeight);
				saveAs("Results", Outputpath +  L_TWindow+currentsignal+ "average.csv");// Save as spreadsheet compatible text file
				run("Results to Image");
				run("Rotate 90 Degrees Right");
				run("Flip Horizontally");
				numcells= getHeight(); 
				timepoints = getWidth();
				
				run("Size...", "width="+timepoints+" height="+expandcelltrack*numcells+" average interpolation=None"); 
				saveAs("tiff", Outputpath + L_TWindow+currentsignal+"average.tif");// Save as image to facilitate visualisation of calcium spikes
				close();
				run("Clear Results"); //otherwise accumulate bigger datasets at the end of smaller ones
				}
			}
	}


if(L_CalciumChannel!=-1)  //check if image actually exists -> should check name of image specifically
	{
	k=maxk-1; // this is only the CaCondensedNormalised, this is sufficient
	currentsignal = ExtendedSignalNames[ProcessedSignalsPreIndex[k]] + ProcessedSignals[k] ;	
		if(isOpen(currentsignal + "average.tif"))
			{
			selectWindow(currentsignal + "average.tif");
			if(CondenseFactor!=1)
				{
				run("Select All"); 
				//timepoints and height obtained earlier 
				//numcells= getHeight(); timepoints = getWidth();
				run("Size...", "width="+timepoints/CondenseFactor +" height="+expandcelltrack*numcells+" average interpolation=Bilinear");
				saveAs("Tiff", Outputpath + L_TWindow+currentsignal+"Condensedaverage.tif"); 
				//now one line per well for the results table
				run("Size...", "width="+timepoints/CondenseFactor +" height="+numcells+" average interpolation=Bilinear");
				run("Flip Horizontally");
				run("Rotate 90 Degrees Left");
				run("Image to Results");
				saveAs("Results", Outputpath + L_TWindow+ currentsignal+"Condensedaverage.csv");// Save as spreadsheet compatible text file
				selectWindow(L_TWindow+currentsignal+"Condensedaverage.tif"); close();
				}
			else close();
		} //if no calcium data then there is nothing to close
	} 

//report cell counts per well for each time window
WellListFile= L_TWindow+"CellsPerWell.csv";
destination= Outputpath + WellListFile;
if (File.exists(destination)) a=File.delete(destination); // must overwrite existing so that we do not accumulate lines
string = "Well"; for (i= 0; i< lengthOf(L_WellList); i++) string = string + "," +  L_WellList[i] ;
File.append(string, destination);
string = "# cells detected"; for (i= 0; i< lengthOf(L_WellList); i++) string = string +","+ CellsPerWell[i] ;
File.append(string, destination);
print("data processing and collation macro completed for " + L_experimentpath);
setBatchMode(false);
}



function collectWindowData(L_parameters_collected_per_channel, L_Channels, L_CalciumChannel, L_SegmentationChannel, L_SignalNamesRGBgroups, L_GroupCount, L_RatioPairs, L_TimeWindowFirst, L_TimeWindowLast,L_TimeWindowStep, L_experimentpath, L_OutputFolderKernel, L_ThresholdCode) // 
{ 
	//check the relevant data folder exists (not whether windows exist, that's another matter)
	OutputFolder = L_OutputFolderKernel+L_ThresholdCode; //	//check the relevant data folder exists (not whether windows exist, that's another matter)
	Outputpath=L_experimentpath+ OutputFolder + File.separator;
	if(!File.exists(Outputpath)) {print("No folder " + Outpath + " from which to collect windowed data."); return;} //don't interrupt analysis of next experiments
	
	if (L_CalciumChannel==-1) L_spikes=false;
	else L_spikes= File.exists(Outputpath+Timewindow+L_SignalNamesRGBgroups[L_CalciumChannel-1] + SpikeRateFromNormalised + "average.csv");  // just checking one well one file to ensure backward compatibility

	
	maxk = L_Channels *L_parameters_collected_per_channel;	 //this includes calcium
	if(L_CalciumChannel !=-1) 
		{
		maxk=maxk+2;//5;		calcium could be recorded in detailed and condensed form, hence an extra channel, but still need 2 extras because the uneroded nuclei are used, also for thresholding; it means nuc and band may be divideby0
		maxk=maxk+2*L_spikes;
		}
	maxk=maxk+4*L_RatioPairs.length; //2 compartments  with and without normalisation 
	

for(GroupNumber=1; GroupNumber<L_GroupCount+1; GroupNumber++) // better to put grouops under well as usual?
	{
	print(printformatter + "Merging data files for "+ L_experimentpath); 
	firstchannel = L_Channels * (GroupNumber -1);	lastchannel = L_Channels * (GroupNumber);
	L_SignalNamesRGB = Array.slice(L_SignalNamesRGBgroups, firstchannel, lastchannel); // 3,6 or 0, 3
	
	if(L_SignalNamesRGB.length>1) //found some channels
			{					
			NonSegmentationImages =newArray(L_SignalNamesRGB.length-1);
			kk=0;
			// find and exclude the segmentation channel, count the rest
			for(i=0; i<L_SignalNamesRGB.length;i++) if(i!=L_SegmentationChannel-1) {NonSegmentationImages[kk]=L_SignalNamesRGB[i];   kk++; }
			}
	
	ProcessedSignals = getProcessedSignals(maxk, L_Channels, L_CalciumChannel, L_parameters_collected_per_channel, L_RatioPairs, L_spikes);
	ProcessedSignalsPreIndex = getProcessedSignalsPreIndex(maxk, L_Channels, L_CalciumChannel, L_parameters_collected_per_channel, L_RatioPairs, L_spikes);
	ExtendedSignalNames = getExtendedSignalNames(L_SignalNamesRGB,RatioPairs); // Remember array is a pointer, so this changes L_SignalNamesRGB
					
	if (Verbosity >0) print("set up variables, now merging csv data files");
			
	for (k = 0; k<maxk; k++) //here and in Collate data this is hard-wired as 3 channels but 6 outputs
		{
		currentsignal = L_SignalNamesRGB[ProcessedSignalsPreIndex[k]] + ProcessedSignals[k] ;
		destination = Outputpath +"AllWindows"+currentsignal+ "average.csv";
		if (File.exists(destination)) a=File.delete(destination); // must overwrite existing so that we do not accumulate lines
		print(printformatter+"generating output " + k + " " +destination);
		
		for (Window=L_TimeWindowFirst; Window<L_TimeWindowLast+1; Window +=L_TimeWindowStep)// for (Window=TimeWindowFirst+TimeWindowStep; Window<TimeWindowLast+1; Window +=TimeWindowStep)
			{	
			Timewindow = "Window_"+Window+"to"+Window+L_TimeWindowStep-1;
			currentfile = Outputpath +  Timewindow+currentsignal+ "average.csv";
			//print(printformatter+"reading "+ currentfile);
			length = File.length(currentfile);
			//print(printformatter+ currentsignal, length);
			if(length!=0)
				{	
				fileasstring= File.openAsRawString(currentfile, length);// - Opens a file and returns up to the first count bytes as a string. 
				print(printformatter+"appending "+ currentfile);
				File.append("Window:,"+ Timewindow, destination);
				File.append(fileasstring, destination);// - Appends string to the end of the specified file. 
				}
			else
				print("file " + currentsignal + " has zero length - check it exists"); //);print("");}
			}
		}	
	//now add cells per well
	// path is the ImagesAlignedtoChX folder 
	destination = Outputpath +"AllWindows"+ "CellsPerWell.csv";
	if (File.exists(destination)) a=File.delete(destination); // must overwrite existing so that we do not accumulate lines
	for (Window=L_TimeWindowFirst; Window<L_TimeWindowLast+1; Window +=L_TimeWindowStep)// for (Window=TimeWindowFirst+TimeWindowStep; Window<TimeWindowLast+1; Window +=TimeWindowStep)
		{
		Timewindow = "Window_"+Window+"to"+Window+L_TimeWindowStep-1;
		print("will collect cells per well from window " + Timewindow);
		currentfile = Outputpath +  Timewindow+ "CellsPerWell.csv";
		print("reading "+ currentfile);
		print("");
		length = File.length(currentfile);
		if(length!=0)
			{	
			fileasstring= File.openAsRawString(currentfile, length);// - Opens a file and returns up to the first count bytes as a string. 
			print(printformatter+"appending "+ currentfile);
			File.append("Window:,"+ Timewindow, destination);
			File.append(fileasstring, destination);// - Appends string to the end of the specified file. 
			}
		else
			print("file " + currentsignal + " has zero length - check it exists"); //);print("");}
		}
			
	}				
}



function getExtendedSignalNames(LL_SignalNamesRGB, L_RatioPairs)
{// Remember array is a pointer, so this changes L_SignalNamesRGB
	ExtendedSignalNames = LL_SignalNamesRGB;
	if (L_RatioPairs.length !=0)
		{
		for (i=0; i<L_RatioPairs.length; i++)
			{
			CurrentPair=split(L_RatioPairs[i], "v"); //cannot use ":" or "/"
			for (j=0;j<2;j++)		
				{	
				NumeratorChannel=parseInt(CurrentPair[0])-1;
				DenominatorChannel=parseInt(CurrentPair[1])-1;
				//L_RatioNames[2*i+j] ="Ratio"+LL_SignalNamesRGB[NumeratorChannel]+"by"+LL_SignalNamesRGB[DenominatorChannel]+compartment[j]+"Thresholded";//!!!!!!!!!!!!!!! not used here?
				ExtendedSignalNames =Array.concat(ExtendedSignalNames,"Ratio"+LL_SignalNamesRGB[NumeratorChannel]+"by"+LL_SignalNamesRGB[DenominatorChannel]);
				}	
			}
		}
	return ExtendedSignalNames;
}



function getProcessedSignals(L_maxk, LL_Channels, L_CaChannel, L_ParamsPerChannel, L_RatioPairs, L_spikes)
{
ProcessedSignals = newArray(L_maxk);
//first section applies to all channels
for (i=0; i<LL_Channels; i++)
	{// populate the 6 signals quantified for each channel
	ProcessedSignals[i] ="cytbynuc"; 
	ProcessedSignals[LL_Channels + i] ="cytbynucNormalised"; 
	ProcessedSignals[2*LL_Channels + i] ="nuc"; 
	ProcessedSignals[3*LL_Channels + i] ="band"; 
	ProcessedSignals[4*LL_Channels + i] ="nucNormalised"; 
	ProcessedSignals[5*LL_Channels + i] ="bandNormalised"; 
	}
	
	if(L_CaChannel!=-1)
	{//edit Ca to "Normalised" for backward compatibility > "CondensedNormalised"
		// note nucNormalised is only the nuclear region, whereas Normalised is the non-eroded segmentation because there was no need to erode - it means the Ca data is not treated the same way
	//maxk was incremented just for these two
	ProcessedSignals[LL_Channels *L_ParamsPerChannel] ="CondensedNormalised"; 
	ProcessedSignals[LL_Channels *L_ParamsPerChannel+1] ="Normalised"; 
	if (L_spikes)
			{
			ProcessedSignals[LL_Channels *L_ParamsPerChannel+2]="SpikeRateFromNormalised"; 
			ProcessedSignals[LL_Channels *L_ParamsPerChannel+3]="SpikeHeightFromNormalised"; 
			}
	/*
	consider in future something like  below, so that condensed data is considered a separate channel?
	i= L_Channels; 
	ProcessedSignals[i] ="cytbynuc"; ProcessedSignalsPreIndex[i] = i; //that's when cyt-by-nuc data is needed
	ProcessedSignals[L_Channels + i] ="cytbynucNormalised"; ProcessedSignalsPreIndex[L_Channels + i] = i; //that's when normalised cyt-by-nuc data is needed
	ProcessedSignals[2*L_Channels + i] ="nuc"; ProcessedSignalsPreIndex[2*L_Channels + i] = i; //that's when raw fluorescence data needed - assuming only "nuclear" (could be whole cell and band is not relevant)
	ProcessedSignals[3*L_Channels + i] ="band"; ProcessedSignalsPreIndex[3*L_Channels + i] = i; 
	ProcessedSignals[4*L_Channels + i] ="nucNormalised"; ProcessedSignalsPreIndex[4*L_Channels + i] = i; 
	ProcessedSignals[5*L_Channels + i] ="bandNormalised"; ProcessedSignalsPreIndex[5*L_Channels + i] = i; 
	*/
	}

if (L_RatioPairs.length !=0)
		{	
		for (i=0; i<L_RatioPairs.length; i++)
			{
			for (j=0;j<2;j++)		
				{	
				ProcessedSignals[L_maxk-4 + 2*(2*i+j)]=compartment[j]; 
				ProcessedSignals[L_maxk-4 +1+ 2*(2*i+j)]=compartment[j]+"Normalised"; 
				}
			}
		}
		
				
return ProcessedSignals;
}

function getProcessedSignalsPreIndex(L_maxk, LL_Channels, L_CaChannel, L_ParamsPerChannel, L_RatioPairs, L_spikes)
{
ProcessedSignalsPreIndex = newArray(L_maxk);
	for (i=0; i<LL_Channels; i++)
		{// populate the 6 signals quantified for each channel
		ProcessedSignalsPreIndex[i] = i; //that's when cyt-by-nuc data is needed
		ProcessedSignalsPreIndex[LL_Channels + i] = i; //that's when normalised cyt-by-nuc data is needed
		ProcessedSignalsPreIndex[2*LL_Channels + i] = i; //that's when raw fluorescence data needed - assuming only "nuclear" (could be whole cell and band is not relevant)
		ProcessedSignalsPreIndex[3*LL_Channels + i] = i; 
		ProcessedSignalsPreIndex[4*LL_Channels + i] = i; 
		ProcessedSignalsPreIndex[5*LL_Channels + i] = i; 
		}
	
	
	if(L_CaChannel!=-1)
		{//edit Ca to "Normalised" for backward compatibility > "CondensedNormalised"
			// note nucNormalised is only the nuclear region, whereas Normalised is the non-eroded segmentation because there was no need to erode - it means the Ca data is not treated the same way
		//maxk was incremented just for these two
		ProcessedSignalsPreIndex[LL_Channels *L_ParamsPerChannel]=L_CaChannel-1;
		ProcessedSignalsPreIndex[LL_Channels *L_ParamsPerChannel+1]=L_CaChannel-1; 
		if (L_spikes)
			{
			ProcessedSignalsPreIndex[LL_Channels *L_ParamsPerChannel+2]=L_CaChannel-1;
			ProcessedSignalsPreIndex[LL_Channels *L_ParamsPerChannel+3]=L_CaChannel-1;
			}
		}
		
		
		if (L_RatioPairs.length !=0)
		{	
		for (i=0; i<L_RatioPairs.length; i++)
			{
			for (j=0;j<2;j++)		
				{	
				ProcessedSignalsPreIndex[L_maxk-4 + 2*(2*i+j)]=LL_Channels+2*i+j; //extend the channel IDs names to include RatioPairs
				ProcessedSignalsPreIndex[L_maxk-4 +1+ 2*(2*i+j)]=LL_Channels+2*i+j; //extend the channel IDs names to include RatioPairs
				}
			}
		}
		
return ProcessedSignalsPreIndex;
}














function CollateThresholdandSignals(L_path, L_well, L_signal, L_TWindow) //returns # of cells in file
{
L_filetoopen = L_path + "Results"+L_TWindow+L_well+L_signal+"ThresholdedCells.tif";
if (Verbosity >2) print(L_filetoopen);
	if (!File.exists(L_filetoopen)) 
	{
	if(Verbosity >2) print(L_filetoopen + " does not exist. Will try next well."); 
	if (nResults !=0)
	//************************************************************************
	// this edit is convenient for excel but will need a modification of the R script to discard this well
	for (i=0; i<nResults; i++)  setResult(L_well, i,NaN); // add a blank column if the well data is not there: don't know the length of other columns yet
	//************************************************************************
	return 0;
	} // skip to next well
open(L_filetoopen); 
NumberOfCells=getHeight();
run("Select All"); 
L_profile = getProfile();//run("Plot Profile");	without plotting:-
  for (i=0; i<L_profile.length; i++)  setResult(L_well, i, L_profile[i]);
  updateResults; //without this the results table will not exist and the calling function will quit silently
  close();
    return NumberOfCells;
	}


function NonFatalError(message) //so far not used as it would disrupt processing of next wells or experiments
{
print(message);
showMessage("Non-Fatal Error", message);
return;
}

function FatalError(message)
{
print(message);
showMessage("Fatal Error - cannot proceed", message);
exit; // cannot proceed
stop;
}

/*version info
//Macro background-subtraction-by-field x all-wells x 3 channel x time-compress_option x align
//Ver8d simplifies Singleimage to stack conversion
//ver e does not create ROIs from zero selections, they are checked first - it works in IJ1.51w
// ver f for alternate C excitation for optoregulators
//v1 191118MJC combining version 9f-preprocessing and 7f-segmenting modules
//v2 011218MJC includes data collation module
//v3a 231218MJC
//v3b 080119MJC
//v3c 081119MJC
//v3d 230119MJC
//v3o 100319MJC
//v3q 120319MJC
//v3q 150319MJC tries to generate unique alignment transformationmatrix files so that multiple instances do not prevent each others' alignments
//v3r-s-t 15-180319MJC implements multicompartment collection of Ca data
//v3u 190319MJC includes ShapeFeatures
//v3v 210319MJC include ERK/JNKcytbynucNormalisedThresholded, implements normaliser function
//v3w 210319MJC expands normaliser functions to two; moves wellconstraints up 
//v3x 230319MJC catches more single frame projection errors and allows smoothing for NuclearROI where Compression x timepoints is low
//v3y 240319MJC tries to fix non-existing results table issues when running data collation module alone
//v3z 250319MJC corrects bugs in data normalisation  when there's only one normaliser timepoint, and cropping features
//v4a 250319MJC segmentation data saved as means only no averages and medians because there's a ShapeFeatures file now; prevented Baseline adjust to window when window option not selected
//v4b 260319MJC saves report for processing, segmenting and Data collecting functions so that it is possible to know what parameters were used
//v4c 270319MJC saves aligned images to its own folder
//v4d 280319MJC corrects error in baseline normalisation point count for FastCa
//v4e 290319MJC fixed folder naming order error regarding alignmentfolder/timewindow for MergedDataPath, and creates window subfolders under segmentation as well as alignment folders
//v4f 290319MJC handles closing of stray files and log window positioning correctly, and does not savea FastCa if there only 1 timepoint!
//v4g 020419MJC replaced "interpolation=Bilinear" with None, to reduce ambiguity when copying single value normalisers, where data as images is normalised to baseline or against max/min
//v4h 030419MJC all references to big i.e. high time resolution data bracketed with if(L_SignalNamesRGB[2]=="Ca")
//v4i 060419MJC reversed buggy edits to errors introduced to MergeWindowFiles section and included Group iteration
//v4j 100619MJC added AlignTimepoints switch
//v4k 100619MJC included renaming of Results Tables to "Results" after .xls saves in version <1.51  because otherwise "Results to Image" will fail
//v4l 110619MJC include AlignTimepoints switch in report
//v4m 140619MJC fixed bug from parsing version number in IJ2: vn=parseFloat(substring(v,0, lengthOf(v)-1)) to vn=parseFloat(substring(v,lengthOf(v)-5, lengthOf(v)-1));
//v4n 150619MJC name the Segmentation and CollatedData folders by Segmentation and Alignment channel used with kernel suffix  AnSn or _AnSn_ respectively
//v4o 170618MJC fixed bug related to segmentation of calcium when there is only one time point or data is windowed 1 at a time
//v4p 200619MJC adapted for 4 channels, still experimental. Does it still work for 3?
//v4q 050719MJC fixed handling of segmentation channel v calcium channel - but changes not all saved in release!
//v4r 160719MJC fixed Align4D inconsistent use of channels&Channels-> L_channels
//v4s 170719MJC fixed image alignment bug introduced in version 4p - generate transformation matrix first before applying it, and if align0 then don't do it.
//v4t 180719MJC new array defining thresholding channels and parameters to apply, documented in reports
//v4t2 220719MJC compatibility update - functions adjusted for consistency
//v4t3 0409019MJC fixed ThresholdCode inconsistencies
//v4u  060919MJC Fiji compatibility - replaced run("Stack Combiner" with run("Combine..."
//v4v 130919MJC adjusting for single channel use...ongoing, and save image used for segmentation, removed extra backgroundsub sliding pre-segmentation that generated  doughnuts at 20x
//v4w 111019MJC fixed bug handling single channel tc, condense factor 1 resulted in single tp image due to failed duplication of stack
//v4x 251119MJC fixed bug missing {} causing crash with no calcium and no timepoints
//v4y 251119MJC i) new segmentation setting parameters added and implemented to function getNucROIs: watershed as an option, ForceSquareRoot to by pass cancellation when there is only one image but it is sufficient quality
//              ii) expanded collected parameters per channel from 2 to n; currently 3 cytbynuc, cytbynucnorm, nuc (no cyt for now). 
//v4z 230120MJC erodecycles correctly passed
//				WARNING Replicate routine under Windows at top still not updated yet!!! -> rationalise this
//v4z1 120220MJC attempt to fix collation in windows - does it work?
//v4z2 120220MJC continuing to fix collation in windows - more to do - include shape files and other missing parameters in line 1800
//v4z3 200220MJC choice of colour coding for merged images
//v4z4 200220MJC fixed crash when data not past threshold because of attempt to close non existing Normalised data files
//v4z5 070320MJC fixed collation bug fixed in 4z3 and back in 4z4
//v4z6 080320MJC startup consistency checks
//v5a1 220720MJC implemented correction factors for geometric distortion from LEXY study. With current 700/75 and new ET620/60 em  filters it looks like it should be applied to both but off centre
//v5a2 220720MJC fixed thresholds reporting bug 
//v5a3 200820MJC allow mismatch threshold array if no thresholds needed; ensure align folder does not indicate alignment when false
//v5a4 210820MJC extending support for >7 colours - have to use hyperstack, which may break subsequent code - testing
//v5b1 041120MJC resolving alignerchannel -1 alignchannel setting conflicts
//v5b2 101120MJC include channel names and dye names in report
//v5c1 131120MJC include workaround for imagej run("image sequence..." bug that occurs when non-standard bmp has earlier create date than the tifs causing the "file=" to be ignored; *.bmp converted to bmp16
//v5c2 021220MJC include validity checker to avoid crashes on incomplete image data (early macro quit); to allow intervention-free processing of subsequent datasets
//v5d1 031220MJC autocomplete probe names if explicit != true
//v5d2 031220MJC autocomplete probe names suppots > 1 probe/dye cycle now
//v5d3 060121MJC allows entry of image runs as a single CSV to be separated
//v5d4 290121MJC fixed error in datestamps (month now starts at 1, has padding)
//v5d5 030221MJC automate platetype determination and no longer attempting to search wells that are not there. Can still consruct a rectangular well array by the corners..
//v5d6 200221MJC Use IJ1.52s stringString.trim to allow spaces in expt name AND permit space between listed names to avoid obscure failed runs
//v5d7 290421MJC include "SaveMergedAsAVI" option and path validation
//v5d8 080721MJC corrected bug in dyetype search function preventing multiple experiment runs with different dye names
//v5d9 100821MJC Data collection per channel in SaveAverageTraces() now systematic. Awaiting fix for corresponding section in timewindows procedure 
//v5d10 310122MJC corrected bug that excluded CaCondensed from data collation
//v5d11 080222MJC add IJ version to reports; separate experiment Runlist loop with existence check from Run processing, so a typo does not kill all runs. Adds failures to error log in the corresponding folder common to all runs so it's easily findable.
//v5d12 090422MJC corrected renaming imagestack to Merged for single cell data, and simplified related if then lines 994- 1019
//v5d13 100522MJC added -1 RB option for function getNuclearROI. Needed for some datasets (iPS neuron single channel Ca) 
//v5d14 120522MJC report erode cycles in segmentation records
//v5d15editing 170522MJC fixed bug in SaveAverageTraces function. Cannot treat calcium data like ktr channels because calcium is thresholded before erosion. 
				//This means nucCalcium etc may contain zeros and normalisation divideby0, so we have to use Calcium not nucCalcium
				editing because the windowed analysis is currently inconsistent
//v5d16editing 191022MJC added file of cells per well detected, rationalised unified well counting in collation code, added a MaxRois parameter to avoid hanging 
//v5d17editing 271022MJC adding wrapper for alignment function to allow NanoJ alignment as an option, added functions  CloseSelectWindow, Fatalerror; added workaraound for a [run("Duplicate] bug (used a random name with v1.53s and v1.53t) in two places in one function				
//v5d17bediting	281022MJC unified reports to generate a single report file per folder for all wells analysed at a time; output field average intesity during Processing step
//v5d18_editing 291022MJC move metadata above well cycle and correct max ROIs based on field count
//v5d19_editing 311022MJC fixed failed image closing when using F4DR, adding a fullyClose() function, and workaround unexpected image title assembly issue uder segmentation
//v5d20_editing 0211022MJC including ratios in data calculations
//v5d20b_editing 031122MJC fixing the data collation for ratios, some simplification and small functions 
//v5d21_editing  061122MJC updated windowed data collection for consistency, now one report for all windows. Added option to segment with StartDist, corrected NanoJ image apply correction bug.
//v5d22 		101122MJC small fixes: working again without windows, field average starting at image 0 not 1. wider border margin for stardist. 
//v5d23			111122MJC fixed the stardist over-the-boundary ROIs with a filter step, cleaned up other ROI filtering steps
//v5d24		141122MJC included ratioing of rapidly acquired calcium by an expression estimate from  slowly acquired ktr probe, for use e.g. when both probes from single vector
				// note 1 Expression estimate normalises nuc and band data by corresponding ROI areas to counter nuc-cyto translocation 
				// note 2 Output named "CabyERK[nuc/band]*" refer to the Canuc/Caband numerator data as the ERK is an expression estimate from both (area normalised
//v5d25		151122MJC removed use of results table for data collection (thresholding) to minimise flashing screens; solved issue whereby 16bit bmps killed image import. Still there in final collation
//v5d26		161122MJC from now on use "1v2" for defining ratios not "1:2" because now recording all settings in a readable form at the start in a time-stamped file.Excel messes up colons
//v5d27		171122MJC now all settings recorded and read back which means that settings file can be copied and reused on other experiments as needed
//v5d28		181122MJC added basic spike analysis (rates and heights by time unit, using Array.findMaxima (could not clearly see use of fourier with only 50 datapoints), checks the files exists when collating to ensure backward compatibility
//v5d28a	191122MJC workarounds to retain spike images as place holders even when no cells; corrected RatioPairs crashing bug in array2str when array is zero length
//v5d29d    281122MJC reading parameter from macro or file, displaing dialog for modification, and writing saved settings. For testing
//v5d29e	031222MJC further corrections e.g. set RatioPairs to newArray() if length =1 but it is "", corrected row/col swap in dialog labels
//v5d29f	041222MJC updates, 
//			provided more informative labels to dialog; check channels have the required data and cannot proceed otherwise, 	
//			added a checkbox and valuebox for defining the widths of bands used? 
//			trims spaces from parameter settings in boxes, so a user entry of a space does not kill the string arrays
//			collationreport now sets return to true so that reportstarted is now tracked
//			usage recorded with date stamp, username, version ids and parameter file
//v5d29g	051222MJC option for experimental algorithm to to define bands in different way to avoid overlap - check Y:\Data\BDand ImagingMacros\_Macros - for segmentation\Bands_without_overlap.ijm
	// this algorigm does not work yet...
// v5d29h	071222MJC add datestamp to FieldAverages, and tru to make datestamp global
// v5d29i   18042023MJC corrected bug that user-defined BandWidth used regardless of value of Modify band compartment width from default
// v5d29j   06-10102023MJC corrected several bugs 
				i) aborting spike collection on one missing well, 
				ii) causing incomplete data collation reports; 
				iii) failure to report band width in segmentation report; 
				iv) workaround for threshold failure caused by nanoJ aligment failure on fastCa - now
				using only the condensed calcium data for thresholding. May need some adjustment if 
				calcium not the segmentation channel, will see when that happens
			also 
				i) cleaned up some threshold array manipulation 
				ii) added a line to generate NaN columns when well data is missing - easier for excel use but I will need to check R scripts can interpret this correctly
// v5d29k	121023MJC bugfix: explicit use of Ca in "Cabignuc" -> replace with L_SignalNamesRGB[L_CalciumChannel-1]+"bignuc";
// v5d29l    180123MJC minor bugfix: line 3159 for single file was out of date, now: for (j=0;j<3lengthOf(ThresholdTypes);j++) {run("Select All");
// v5d29m    020223MJC typo in previous minor bugfix!!: line 3159 for single file was out of date, now: for (j=0;j<lengthOf(ThresholdTypes);j++) {run("Select All");
 run("Duplicate...", "title="+L_SignalNamesRGB[i]+ThresholdTypes[j]+" duplicate");};
//v5e1a		240212-13MJC introduced an adaptive band algorithm I have generated and checked seperately, improve, debug and adjust to fit this script

// TODO ** should generate compressed versions of ratio data that include Ca data because these have many timepoints and cannot be aligned as they are
// TODO *  use passed parameter array in main functions

*/




