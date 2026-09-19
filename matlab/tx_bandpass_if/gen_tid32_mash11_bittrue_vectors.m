function gen_tid32_mash11_bittrue_vectors(output_dir, words, seed)
%GEN_TID32_MASH11_BITTRUE_VECTORS Generate MATLAB oracle vectors for RTL.
if nargin < 2, words=128; end
if nargin < 3, seed=20260916; end
if ~isfolder(output_dir), mkdir(output_dir); end
rng(seed); l=32;
iw=int64(randi([-12000,12000],l,words));
qw=int64(randi([-12000,12000],l,words));
s=[]; pa1=false(2*l,words); pa2=false(2*l,words);
for n=1:words
    [pa1(:,n),pa2(:,n),s]=tid_mash11_pipelined_step(iw(:,n),qw(:,n),s,16);
end
local_words(fullfile(output_dir,'tidmash_i.mem'),iw(:),16);
local_words(fullfile(output_dir,'tidmash_q.mem'),qw(:),16);
local_words(fullfile(output_dir,'tidmash_pa1.mem'),pa1(:),1);
local_words(fullfile(output_dir,'tidmash_pa2.mem'),pa2(:),1);
end

function local_words(path,x,w)
fid=fopen(path,'w'); assert(fid>=0,'Cannot open %s',path);
cleanup=onCleanup(@()fclose(fid)); mask=int64(2)^w-1;
for k=1:numel(x), fprintf(fid,['%0',num2str(ceil(w/4)),'X\n'],mod(int64(x(k)),mask+1)); end
end
