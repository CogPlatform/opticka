function addOptickaToPath()
% adds opticka to path, ignoring at least some of the unneeded folders
mpath			= path;
mpath			= strsplit(mpath, pathsep);
opath			= fileparts(mfilename('fullpath'));

%remove any old paths
opathesc		= regexptranslate('escape',opath);
oldPath		= ~cellfun(@isempty,regexpi(mpath,opathesc));
if any(oldPath)
	rmpath(mpath{oldPath});
end

% add new paths
opaths		= genpath(opath); 
opaths		= strsplit(opaths,pathsep);
sep 			= regexptranslate('escape',filesep);
pathExceptions = [sep '\.git|' sep 'adio|' sep 'arduino|' sep 'photodiode'];
qAdd 			= cellfun(@isempty,regexpi(opaths,pathExceptions)); % true where regexp _didn't_ match
addpath(opaths{qAdd}); savepath;
disp('--->>> Added opticka to the path...')