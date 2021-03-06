



 The easiest thing to do then is to modify the headers of the images 
that have been spatiallly normalised to the DARTEL average by pasting the 
following text into MATLAB, and selecting the appropriate files:

% Select files
PN = spm_select(1,'.*_sn.mat','Select sn.mat file');
PI = spm_select(inf,'nifti','Select images');

% Determine affine transform from header
sn    = load(deblank(PN));
M     = sn.VG(1).mat/(sn.VF(1).mat*sn.Affine);

% Scaling by inverse of Jacobian determinant, so that
% total tissue volumes are preserved.
scale = 1/abs(det(M(1:3,1:3)));

% Pre-multiply existing headers by affine transform
for i=1:size(PI,1),

    % Read header
    Ni     = nifti(deblank(PI(i,:)));

    % Pre-multiply existing header by affine transform
    Ni.mat = M*Ni.mat;
    Ni.mat_intent='MNI152';

    % Change the scalefactor.  This is like doing a "modulation"
    Ni.dat.scl_slope = Ni.dat.scl_slope*scale;

    % Write the header
    create(Ni);
end 