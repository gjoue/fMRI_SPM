%%-------------------------------------------------------------------------
%%                   2.  SLICE-TIMING CORRECTION
%%-----------------------------------------------------------------

%% Do slice-timing correction before realignmt for interleaved acquisitions; 
%%  multiband sequences acquire slices in either ascending or descending interleaved order, 
%%  depending on which direction the slices were prescribed (the nifti header should indicate whether it's ascending or descending -- 
%%  For mux>1, multiple slices are acquired simultaneously. 
%%   e.g., for a mux 3 scan with 14 muxed slices (that will result in 14*3=42 unmuxed slices), 
%%          the acq. order is [1,3,5,7,9,11,13,2,4,6,8,10,12,14]. 
%%          And mux slice 1 will get reconstructed as unmuxed slices [1,15,29], which are all acquired simultaneously. 
%%         Likewise, mux slice 2 will get deconvolved into unmuxed slices [2,16,30]. 
%%
%%  algorithm to compute the relative slice acquisition time within the TR:
%%
%   mux = 3
%   nslices = 5
%   tr = 1.0
%   mux_slice_acq_order = range(0,nslices,2) + range(1,nslices,2)
%   mux_slice_acq_time = [float(s)/nslices*tr for s in xrange(nslices)]
%   unmux_slice_acq_order = [nslices*m+s for m in xrange(mux) for s in mux_slice_acq_order]
%   slice_time = {slice_num:slice_time for slice_num,slice_time in zip(unmux_slice_acq_order, mux_slice_acq_time*3)}
%   for slice,acq in sorted(slice_time.items()):
%       print "    slice %02d acquired at time %.3f sec" % (slice+1,acq)
%
%%   slice 01 acquired at time 0.000 sec
%%   slice 03 acquired at time 0.200 sec
%%   slice 05 acquired at time 0.400 sec
%%   slice 02 acquired at time 0.600 sec
%%   slice 04 acquired at time 0.800 sec
%%   slice 06 acquired at time 0.000 sec
%%   slice 08 acquired at time 0.200 sec 
%%
%% For Siemens, look in header -- DICOM files at ISfN are here /common/mrt0/prisma/images/
% hdr=spm_dicom_headers('testDICOM')
% format bank
% cfg.MRI.ST=hdr{1}.Private_0019_1029

function jobs = PREPROC_ST(dirTask,cfg)
    cd(dirTask)
    runs = get_subfolders('.');
    for rr = 1:length(runs)
        run = runs{rr};

        fprintf('%s, %s\n', dirTask, run);
        dirRun = fullfile(dirTask,run);
            
        img = spm_select('FPList',dirRun,'^f.*nii$');
        jobs{1}.spm.temporal.st.scans{rr} = cellstr(img);
    end     

    jobs{1}.spm.temporal.st.nslices  = cfg.MRI.nslices; % Anzahl der Schichten vom Kopf oben nach unten
    jobs{1}.spm.temporal.st.tr       = cfg.MRI.TR;
    jobs{1}.spm.temporal.st.ta       = cfg.MRI.TA;      % acquisition time: vom anfang der ersten schicht bis zum anfang der letzten schicht.  

    jobs{1}.spm.temporal.st.so       = cfg.MRI.ST;                             
    jobs{1}.spm.temporal.st.refslice = cfg.PREPROC.STrefSlice; %928.125;

    jobs{1}.spm.temporal.st.prefix = 'a'; 

end
