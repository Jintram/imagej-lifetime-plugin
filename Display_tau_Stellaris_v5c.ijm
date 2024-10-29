//Macro to display lifetime images from Leica Stellaris Falcon
//This requires a saved raw output image with two channels, intensity+lifetime, with lifetimes scaled between 0-10 ns set at the Stellaris microscope
// version5 10-1-2024 Corrected small bug for non square input  figures and included better scaling of text
// version4 10-3-2023 Added processing of multi-channel/timelapse raw FLIM images
// version3 25-2-2023 Added processing of entire directory and average image statistics logfile
// version2 24-2-2023 Added optional thresholding, scale bar and image data info
//Created 23-2-2023 Dorus Gadella


Dialog.create("Input for Lifetime Display");

Dialog.addChoice("What to process ",newArray("Process single file","Process entire directory","Process current image"),"Process single file");
Dialog.addNumber("Minimal Tau for display (ns)  :", 0);
Dialog.addNumber("Maximal Tau for display (ns)  :", 8);
Dialog.addCheckbox("Automatic determination of Intensity threshold", true);
Dialog.addNumber("Minimum image intensity for lifetime statistics/display:", 50);
Dialog.addNumber("Maximum image intensity for lifetime statistics/display:", 250);
Dialog.addCheckbox("Zero lifetime image data outside intensity threshold", true);
Dialog.addNumber("Gamma_for_Intensity            :", 0.7);
Dialog.addNumber("Median filter size to smooth lifetime image (type 0 to not smooth):", 3);
Dialog.addChoice("Colortable for Lifetime Images:",newArray("Fire","Grays","Ice","Rainbow RGB","Gyr_centre","Red Hot", "Royal","16_colors","Green Fire Blue", "Phase", "mpl-plasma"),"Fire");
Dialog.addCheckbox("Print scale bar", true);
Dialog.addNumber("If yes for scalebar length in  µm           :", 10);
Dialog.addCheckbox("Add lifetime histograms", true);
Dialog.addChoice("Save stack or 2D montage",newArray("Stack","Montage"),"Montage");
Dialog.addCheckbox("Write logfile with statistics:", true);
Dialog.addString("Output extension of filename", "_ij.tif");

Dialog.show();
choice_open= Dialog.getChoice();
taumin = Dialog.getNumber();
taumax = Dialog.getNumber();
automax= Dialog.getCheckbox();
imin = Dialog.getNumber();
imax = Dialog.getNumber();
zero= Dialog.getCheckbox();
gamma = Dialog.getNumber();
mediansize = Dialog.getNumber();
colortable=Dialog.getChoice();
scale_yes= Dialog.getCheckbox();
bar_size= Dialog.getNumber();
his_yes= Dialog.getCheckbox();
saveoption=Dialog.getChoice();
log_choice= Dialog.getCheckbox();
extension = Dialog.getString();
//end input

setBatchMode(true);
suffix=".tif";
if (choice_open=="Process single file") {
	open();
	
	files=1;
	filedir = getDirectory("image"); 

	fn=getTitle();
	filedate=File.dateLastModified(filedir+fn);

}else if (choice_open=="Process current image") {
	files=1;
	getDateAndTime(year,month,dw,dm,hr,mi,sec,msec);
	month=month+1;
	filedate=" "+dm+"-"+month+"-"+year;
	print(filedate);
	
	
}else if (choice_open=="Process entire directory") {
	waitForUser("Please select one raw converted FLIM stack in the directory that you want to process");
//	open();
	run("Bio-Formats (Windowless)");
	filedir = getDirectory("image"); 
	close();
	list2=getFileList(filedir);
	list=list2;
	nfiles=list.length;
	files=0;
	for (ifile=0;ifile<nfiles;ifile++) {
		test2=0;
		string=list[ifile];
		test2=endsWith(string, suffix);
		if (test2==1) {
			list[files]=list2[ifile];
			files=files+1;		
		}
	}
}
logje=0;
//start of main loop over all images in directory
//for (ifile=0;ifile<files;ifile++) {
//
//	print(list[ifile]);
//}

for (ifile=0;ifile<files;ifile++) {
	if (files>1) {
		open(filedir+list[ifile]);
		filedate=File.dateLastModified(filedir+list[ifile]);
	}
fn=getTitle();
filedir = getDirectory("image"); 
dotIndex = indexOf(fn, "."); 
filein = substring(fn, 0, dotIndex); 
	metadata2=getImageInfo();
	metadata3="";
	metadata=split(metadata2,"\n");
	z=nSlices();
	y=getHeight();
	x=getWidth();
	getDateAndTime(year,month,dw,dm,hr,mi,sec,msec);
month=month+1;
// below is to get the resolution of the image out of the file info. This is in pixels/µm.
for (j=0;j<metadata.length;j++) {
	if(startsWith(metadata[j],"Resolution:")==true) {
		sinfo=split(metadata[j],":");
		res=sinfo[1];
		sinfo=split(res,"pixels ");
		res=sinfo[0];
	}
}
run("Set Scale...", "distance="+res+" known=1 unit=µm");
scalebar=bar_size*res;
run("32-bit");
numstacks=z/2;
extension_new=extension;
for (jj=0;jj<numstacks;jj++){
if (numstacks>1) extension_new="_"+(jj+1)+extension;
selectWindow(fn);
// loop over time points or channels
setSlice(2*jj+1);
run("Duplicate...", " ");
rename("Int");
getStatistics(area,mean,min,max);
resetMinAndMax();
if (automax==false){
		setMinAndMax(imin,imax);
}else{
	imax=max;
	imin=0.1*imax;
}
run("Duplicate...", " ");
rename("Thres");
setThreshold(imin,imax);
run("Make Binary", "method=Default background=Default only");
run("Divide...", "value=255");
selectWindow("Int");
run("8-bit");
run("Gamma...", "value="+gamma);
selectWindow(fn);
setSlice(2*jj+2);
run("Duplicate...", " ");
rename("taui");
run("Divide...", "value=6553.5");
// the above number is the 16-bit 65536 divided by the lifetime full scale in the saved image (10 ns). If other values were used the number can be changed
if (mediansize!=0) run("Median...", "radius="+mediansize);
if (zero==true) imageCalculator("Multiply", "taui", "Thres");
setMinAndMax(taumin, taumax);
nnn=floor(taumax-taumin)+1;
if (nnn<=2) nnn=2*floor(taumax-taumin)+1;
run(colortable);
if (y<x) {
	hs=y*2/3;
} else {
	hs=x*2/3;
}
hs=round(hs);
zoomfactor=hs/512;
run("Calibration Bar...", "location=[Upper Left] fill=White label=Black number="+nnn+" decimal=1 font=12 zoom="+zoomfactor);
rename("Tau");

selectWindow("taui");
run("Duplicate...", " ");
rename("tau_forhis");
selectWindow("taui");
run("8-bit");
run("RGB Color");

run("RGB Split");
imageCalculator("Multiply create 32-bit", "taui (blue)","Int");
setMinAndMax(0, 65535);
run("8-bit");
rename("out (blue)");
selectWindow("taui (blue)");
close();
imageCalculator("Multiply create 32-bit", "taui (green)","Int");
setMinAndMax(0, 65535);
run("8-bit");
rename("out (green)");
selectWindow("taui (green)");
close();
imageCalculator("Multiply create 32-bit", "taui (red)","Int");
setMinAndMax(0, 65535);
run("8-bit");
rename("out (red)");
selectWindow("taui (red)");
close();
run("RGB Merge...", "red=[out (red)] green=[out (green)] blue=[out (blue)] gray=*None*");
rename("Tau-int");
selectWindow("Int");
run("32-bit");
fo=filein+extension_new;
z=3;
if(his_yes==true) z=4;
newImage(fo,"RGB",x,y,z);
setSlice(1);
selectWindow("Int");
fontsize=hs/20;
bar_dim=hs/330*4;
run("Scale Bar...", "width="+bar_size+" height=1 thickness="+bar_dim+" font="+fontsize+" color=White background=None location=[Lower Right] horizontal bold");
run("Copy");
selectWindow(fo);
run("Paste");
setSlice(2);
selectWindow("Tau");
run("Copy");
selectWindow(fo);
run("Paste");
setSlice(3);
selectWindow("Tau-int");
run("Copy");
selectWindow(fo);
run("Paste");
if(his_yes==true){
	selectWindow("tau_forhis");
	imageCalculator("Multiply", "tau_forhis", "Thres");
	close("Thres");
	if (y<x) {
		hs=y*2/3;
	} else {
		hs=x*2/3;
	}
	hs=round(hs);
	getHistogram(values,histau,hs,taumin,taumax);
	histau[0]=0;
	histau[hs-1]=0;
	nn=0;xsum=0;x2sum=0;hismax=0;
	for (i = 0; i < hs; i++) {
		nn=nn+histau[i];
		xs=values[i]*histau[i];
		x2s=values[i]*values[i]*histau[i];
		xsum=xsum+xs;
		x2sum=x2sum+x2s;
		if(hismax<histau[i]) hismax=histau[i];
	}
		tau_mean=xsum/nn;
		tau_sd=sqrt((x2sum-xsum*xsum/nn)/(nn-1));
//print(tau_mean, tau_sd,x2sum,xsum, nn);

}
selectWindow("tau_forhis");
run("Multiply...", "value=0");
run("8-bit");
run("Grays");


for (i=0; i<hs; i++) {
	ic=i*255/hs;
	iin=histau[i]/hismax*hs;
	if( nn==0) iin=0;
	setColor(ic,ic,ic);
	ii=i+0.25*hs;
	drawLine(ii,hs+10,ii,hs-iin);
}
setColor(255,255,255);
drawLine(0.25*hs,hs,1.25*hs,hs);
setFont("Sans Serif",hs/20, "Plain");
drawString(taumin, 0.25*hs-10, hs*1.1);
drawString(taumax, 1.25*hs-10, hs*1.1);
drawString("tau (ns)", 0.4*x, hs*1.1);
drawString("Average tau="+tau_mean+"±"+tau_sd+" ns", 0.1*x, hs*1.2);
drawString(fn,  0.1*x,hs*1.3);
drawString(dm+"-"+month+"-"+year+"  "+hr+":"+mi+":"+sec,0.1*x,hs*1.35);

setMinAndMax(0, 255);
run(colortable);
run("RGB Color");
run("Copy");
selectWindow(fo);
setSlice(4);
run("Paste");

setSlice(1);

if(saveoption=="Montage") {
	run("Make Montage...", "columns="+z+" rows=1 scale=1 border=1 use");
	close(fo);
}
save(filedir+fo);
close("Tau");
close("Int");
close("Tau-int");
close("tau_forhis");
if (jj==(numstacks-1)) close(fn);
if (files>1) close("Montage");
if(log_choice==1){
	if((logje+jj)==0){
		
  		print("  ");
		print("Conversion start at: "+dm+"-"+month+"-"+year+"  "+hr+":"+mi+":"+sec);
		print("Directory for sample files: "+filedir);
		print("--------------Sample statistics--------------");
		print("filename \tfile creation date\tchannel/time point\ttau (ns)\tsd_tau (ns)\tMinimal Intensity\tMaximal intensity"); 
		logje=1;
	}
	print(fn+"\t"+filedate+"\t"+(jj+1)+"\t"+tau_mean+"\t"+tau_sd+"\t"+imin+"\t"+imax);
}
//end of main loop over all images in directory below
}
}
setBatchMode("exit and display");

