function [data]=getDCT(dimension,file)
A=imread(file);%'mountain/1.jpg'
B=imresize(A,[248,500]);%248*500*3,3403������,RGB
%imshow()
%�任��YBR��ɫ�ռ�
size_B=size(B);
C=zeros(size_B(1),size_B(2),size_B(3));
C(:,:,1)=B(:,:,1).*0.299+B(:,:,2).*0.587+B(:,:,3).*0.114;%YBR
C(:,:,2)=B(:,:,3);
C(:,:,3)=B(:,:,1);

%����ֿ����
size_C=size(C);
row=floor((size_C(1)-2)/6);%���Ŷ��ٸ�
column=floor((size_C(2)-2)/6);
%�Ⱥ���Ų��������Ų,�õ�D
D=zeros(row*column,8,8,3);
 row_status=1;%�ڼ���
 column_status=1;
 %C(2,1,1,:)=ones(1,1,1,3);
 %C(2,1,1,:)
for row_status=1:row  %����Ų��
    for column_status=1:column %����Ų��
        status=column*(row_status-1)+column_status; 
        for ii=1:8
            for jj=1:8
        D(status,ii,jj,:)=C(6*(row_status-1)+ii,6*(column_status-1)+jj,:);
            end
        end
    end
end


%�Էֿ�Ϊ��λ����,�õ�F��ÿһ��Ϊһ�������192�и�����
%F1=zeros(row*column,64,3);
data=zeros(row*column,64*3);
for tt=1:row*column
    for ff=1:3
        %F1(tt,:,ff)=dct2(D(tt,:,:,ff));
        data(tt,ff:3:end)=dct2(D(tt,:,:,ff));
    end
end
data=data(:,1:dimension);%ȡǰ30ά

end
