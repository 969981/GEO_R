#if (!requireNamespace("BiocManager", quietly = TRUE))
#    install.packages("BiocManager")
#BiocManager::install("limma")


library(limma)               
expFile="GSE33000geneMatrix.txt"     
conFile="GSE33000s1.txt"            
treatFile="GSE33000s2.txt"    
setwd(".\\input")    

rt=read.table(expFile, header=T, sep="\t", check.names=F)
rt=as.matrix(rt)
rownames(rt)=rt[,1]
exp=rt[,2:ncol(rt)]
dimnames=list(rownames(exp),colnames(exp))
data=matrix(as.numeric(as.matrix(exp)),nrow=nrow(exp),dimnames=dimnames)
data=avereps(data)

s1=read.table(conFile, header=F, sep="\t", check.names=F)
sampleName1=as.vector(s1[,1])
conData=data[,sampleName1]

s2=read.table(treatFile, header=F, sep="\t", check.names=F)
sampleName2=as.vector(s2[,1])
treatData=data[,sampleName2]


rt=cbind(conData, treatData)

qx=as.numeric(quantile(rt, c(0, 0.25, 0.5, 0.75, 0.99, 1.0), na.rm=T))
LogC=( (qx[5]>100) || ( (qx[6]-qx[1])>50 && qx[2]>0) )
if(LogC){
  rt[rt<0]=0
  rt=log2(rt+1)}
data=normalizeBetweenArrays(rt)

conNum=ncol(conData)
treatNum=ncol(treatData)
Type=c(rep("Control",conNum),rep("Treat",treatNum))
outData=rbind(id=paste0(colnames(data),"_",Type),data)
write.table(outData, file="normalize.txt", sep="\t", quote=F, col.names=F)


library(limma)             
expFile="normalize.txt"    
geneFile="gene.txt"        

rt=read.table(expFile, header=T, sep="\t", check.names=F)
rt=as.matrix(rt)
rownames(rt)=rt[,1]
exp=rt[,2:ncol(rt)]
dimnames=list(rownames(exp),colnames(exp))
data=matrix(as.numeric(as.matrix(exp)),nrow=nrow(exp),dimnames=dimnames)
data=avereps(data)

gene=read.table(geneFile, header=F, sep="\t", check.names=F)
sameGene=intersect(as.vector(gene[,1]), rownames(data))
geneExp=data[sameGene,]

out=rbind(ID=colnames(geneExp), geneExp)
write.table(out, file="GeneExp.txt", sep="\t", quote=F, col.names=F)

library(limma)
library(pheatmap)
library(reshape2)
library(ggpubr)

expFile="GeneExp.txt"  


rt=read.table(expFile, header=T, sep="\t", check.names=F)
rt=as.matrix(rt)
rownames(rt)=rt[,1]
exp=rt[,2:ncol(rt)]
dimnames=list(rownames(exp),colnames(exp))
data=matrix(as.numeric(as.matrix(exp)),nrow=nrow(exp),dimnames=dimnames)
data=avereps(data)
exp=data

Type=gsub("(.*)\\_(.*)", "\\2", colnames(data))

sigVec=c()
sigGeneVec=c()
for(i in row.names(data)){
  test=wilcox.test(data[i,] ~ Type)
  pvalue=test$p.value
  Sig=ifelse(pvalue<0.001,"***",ifelse(pvalue<0.01,"**",ifelse(pvalue<0.05,"*","")))
  if(pvalue<0.05){
    sigVec=c(sigVec, paste0(i, Sig))
    sigGeneVec=c(sigGeneVec, i)}
}
data=data[sigGeneVec,]
outTab=rbind(ID=colnames(data), data)
write.table(outTab, file="diffGeneExp.txt", sep="\t", quote=F, col.names=F)
row.names(data)=sigVec

names(Type)=colnames(data)
Type=as.data.frame(Type)
pdf(file="heatmap.pdf", width=7, height=4.5)
pheatmap(data,
         annotation=Type,
         color = colorRampPalette(c(rep("blue",2), "white", rep("red",2)))(100),
         cluster_cols =F,
         cluster_rows =T,
         scale="row",
         show_colnames=F,
         show_rownames=T,
         fontsize=7,
         fontsize_row=7,
         fontsize_col=7)
dev.off()

exp=as.data.frame(t(exp))
exp=cbind(exp, Type=Type)
data=melt(exp, id.vars=c("Type"))
colnames(data)=c("Type", "Gene", "Expression")

p=ggboxplot(data, x="Gene", y="Expression", color = "Type", 
            xlab="",
            ylab="Gene expression",
            legend.title="Type",
            palette = c("blue", "red"),
            add="point",
            width=0.8)
p=p+rotate_x_text(60)
p1=p+stat_compare_means(aes(group=Type),
                        method="wilcox.test",
                        symnum.args=list(cutpoints = c(0, 0.001, 0.01, 0.05, 1), symbols = c("***", "**", "*", " ")),
                        label = "p.signif")

pdf(file="boxplot.pdf", width=7, height=5)
print(p1)
dev.off()

#install.packages("RCircos")


library("RCircos")  


cytoBandIdeogram=read.table("refer.txt", header=T, sep="\t", check.names=F)
chr.exclude <- NULL
cyto.info <- cytoBandIdeogram
tracks.inside <- 4
tracks.outside <- 0
RCircos.Set.Core.Components(cyto.info, chr.exclude, tracks.inside, tracks.outside)

rcircos.params <- RCircos.Get.Plot.Parameters()
rcircos.params$text.size=0.7
rcircos.params$point.size=5
RCircos.Reset.Plot.Parameters(rcircos.params)

pdf(file="RCircos.pdf", width=7, height=7)
RCircos.Set.Plot.Area()
RCircos.Chromosome.Ideogram.Plot()

RCircos.Gene.Label.Data=read.table("Rcircos.geneLabel.txt", header=T, sep="\t", check.names=F)
name.col <- 4
side <- "in"
track.num <- 1
RCircos.Gene.Connector.Plot(RCircos.Gene.Label.Data, track.num, side)
track.num <- 2
RCircos.Gene.Name.Plot(RCircos.Gene.Label.Data, name.col, track.num, side)
dev.off()

#install.packages("corrplot")
#install.packages("circlize")


library(corrplot)
library(circlize)

inputFile="diffGeneExp.txt"    


data=read.table(inputFile, header=T, sep="\t", check.names=F, row.names=1)

group=gsub("(.*)\\_(.*)", "\\2", colnames(data))
data=data[,group=="Treat",drop=F]
rt=t(data)

cor1=cor(rt)
col = c(rgb(1,0,0,seq(1,0,length=32)),rgb(0,1,0,seq(0,1,length=32)))
cor1[cor1==1]=0
c1 = ifelse(c(cor1)>=0,rgb(1,0,0,abs(cor1)),rgb(0,1,0,abs(cor1)))
col1 = matrix(c1,nc=ncol(rt))


pdf(file="circos.pdf", width=7, height=7)
par(mar=c(2,2,2,4))
circos.par(gap.degree=c(3,rep(2, nrow(cor1)-1)), start.degree = 180)
chordDiagram(cor1, grid.col=rainbow(ncol(rt)), col=col1, transparency = 0.5, symmetric = T)
par(xpd=T)

colorlegend(col, vertical = T,labels=c(1,0,-1),xlim=c(1.1,1.3),ylim=c(-0.4,0.4))
dev.off()
circos.clear()

pdf(file="corrplot.pdf", width=7, height=7)
corrplot(cor1,
         method = "pie",
         order = "hclust",
         type = "upper",
         col=colorRampPalette(c("green", "white", "red"))(50)
)
dev.off()


#BiocManager::install("preprocessCore")
inputFile="normalize.txt"     
source("geo.CIBERSORT.R")       

outTab=CIBERSORT("ref.txt", inputFile, perm=1000, QN=T)

outTab=outTab[outTab[,"P-value"]<0.05,]
outTab=as.matrix(outTab[,1:(ncol(outTab)-3)])
outTab=rbind(id=colnames(outTab),outTab)
write.table(outTab, file="CIBERSORT-Results.txt", sep="\t", quote=F, col.names=F)

#install.packages("reshape2")
#install.packages("ggpubr")



library(reshape2)
library(ggpubr)

inputFile="CIBERSORT-Results.txt"   

rt=read.table(inputFile, header=T, sep="\t", check.names=F, row.names=1)
con=grepl("_Control", rownames(rt), ignore.case=T)
treat=grepl("_Treat", rownames(rt), ignore.case=T)
conData=rt[con,]
treatData=rt[treat,]
conNum=nrow(conData)
treatNum=nrow(treatData)
data=t(rbind(conData,treatData))

pdf(file="barplot.pdf", width=14.5, height=8.5)
col=rainbow(nrow(data), s=0.7, v=0.7)
par(las=1,mar=c(8,5,4,16),mgp=c(3,0.1,0),cex.axis=1.5)
a1=barplot(data,col=col,xaxt="n",yaxt="n",ylab="Relative Percent",cex.lab=1.8)
a2=axis(2,tick=F,labels=F)
axis(2,a2,paste0(a2*100,"%"))
par(srt=0,xpd=T)
rect(xleft = a1[1]-0.5, ybottom = -0.01, xright = a1[conNum]+0.5, ytop = -0.06,col="green")
text(a1[conNum]/2,-0.035,"Control",cex=1.8)
rect(xleft = a1[conNum]+0.5, ybottom = -0.01, xright =a1[length(a1)]+0.5, ytop = -0.06,col="red")
text((a1[length(a1)]+a1[conNum])/2,-0.035,"Treat",cex=1.8)
ytick2 = cumsum(data[,ncol(data)])
ytick1 = c(0,ytick2[-length(ytick2)])
legend(par('usr')[2]*0.98,par('usr')[4],legend=rownames(data),col=col,pch=15,bty="n",cex=1.2)
dev.off()

#if (!requireNamespace("BiocManager", quietly = TRUE))
#    install.packages("BiocManager")
#BiocManager::install("limma")

#install.packages("tidyverse")
#install.packages("ggplot2")
#install.packages("reshape2")

library(limma)
library(reshape2)
library(tidyverse)
library(ggplot2)

expFile="diffGeneExp.txt"          
immFile="CIBERSORT-Results.txt"    

rt=read.table(expFile, header=T, sep="\t", check.names=F)
rt=as.matrix(rt)
rownames(rt)=rt[,1]
exp=rt[,2:ncol(rt)]
dimnames=list(rownames(exp),colnames(exp))
data=matrix(as.numeric(as.matrix(exp)),nrow=nrow(exp),dimnames=dimnames)
data=avereps(data)

group=gsub("(.*)\\_(.*)", "\\2", colnames(data))
data=data[,group=="Treat",drop=F]
data=t(data)

immune=read.table(immFile, header=T, sep="\t", check.names=F, row.names=1)
sameSample=intersect(row.names(data), row.names(immune))
data=data[sameSample,,drop=F]
immune=immune[sameSample,,drop=F]

outTab=data.frame()
for(cell in colnames(immune)){
  if(sd(immune[,cell])==0){next}
  for(gene in colnames(data)){
    x=as.numeric(immune[,cell])
    y=as.numeric(data[,gene])
    corT=cor.test(x,y,method="spearman")
    cor=corT$estimate
    pvalue=corT$p.value
    text=ifelse(pvalue<0.001,"***",ifelse(pvalue<0.01,"**",ifelse(pvalue<0.05,"*","")))
    outTab=rbind(outTab,cbind(Gene=gene, Immune=cell, cor, text, pvalue))
  }
}

outTab$cor=as.numeric(outTab$cor)
pdf(file="cor.pdf", width=7, height=5)
ggplot(outTab, aes(Immune, Gene)) + 
  geom_tile(aes(fill = cor), colour = "grey", size = 1)+
  scale_fill_gradient2(low = "#5C5DAF", mid = "white", high = "#EA2E2D") + 
  geom_text(aes(label=text),col ="black",size = 3) +
  theme_minimal() +    
  theme(axis.title.x=element_blank(), axis.ticks.x=element_blank(), axis.title.y=element_blank(),
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8, face = "bold"),   
        axis.text.y = element_text(size = 8, face = "bold")) +       
  labs(fill =paste0("***  p<0.001","\n", "**  p<0.01","\n", " *  p<0.05","\n", "\n","Correlation")) +   
  scale_x_discrete(position = "bottom")      
dev.off()

#if (!requireNamespace("BiocManager", quietly = TRUE))
#    install.packages("BiocManager")
#BiocManager::install("ConsensusClusterPlus")


library(ConsensusClusterPlus)      
expFile="diffGeneExp.txt"          
setwd(workDir)     

data=read.table(expFile, header=T, sep="\t", check.names=F, row.names=1)
data=as.matrix(data)

group=sapply(strsplit(colnames(data),"\\_"), "[", 2)
data=data[,group=="Treat"]

maxK=9  
results=ConsensusClusterPlus(data,
                             maxK=maxK,
                             reps=50,
                             pItem=0.8,
                             pFeature=1,
                             title=workDir,
                             clusterAlg="km",
                             distance="euclidean",
                             seed=123456,
                             plot="png")

calcICL(results, title="consensusScore", plot="png")


clusterNum=2       
cluster=results[[clusterNum]][["consensusClass"]]
cluster=as.data.frame(cluster)
colnames(cluster)=c("Cluster")
cluster$Cluster=paste0("C", cluster$Cluster)
outTab=cbind(t(data), cluster)
outTab=rbind(ID=colnames(outTab), outTab)
write.table(outTab, file="cluster.txt", sep="\t", quote=F, col.names=F)


#if (!requireNamespace("BiocManager", quietly = TRUE))
#    install.packages("BiocManager")
#BiocManager::install("limma")

#install.packages("pheatmap")
#install.packages("reshape2")
#install.packages("ggpubr")


library(limma)
library(pheatmap)
library(reshape2)
library(ggpubr)

clusterFile="cluster.txt"     


rt=read.table(clusterFile, header=T, sep="\t", check.names=F, row.names=1)
rt=rt[order(rt$Cluster),]


data=t(rt[,1:(ncol(rt)-1),drop=F])
Type=rt[,ncol(rt),drop=F]


bioCol=c("#0066FF","#FF0000","#FF9900","#6E568C","#7CC767","#223D6C","#D20A13","#FFD121","#088247","#11AA4D")
ann_colors=list()
crgCluCol=bioCol[1:length(levels(factor(Type$Cluster)))]
names(crgCluCol)=levels(factor(Type$Cluster))
ann_colors[["Cluster"]]=crgCluCol

pdf("heatmap.pdf", width=7, height=4.5)
pheatmap(data,
         annotation=Type,
         annotation_colors = ann_colors,
         color = colorRampPalette(c(rep("blue",2), "white", rep("red",2)))(100),
         cluster_cols =F,
         cluster_rows =T,
         scale="row",
         show_colnames=F,
         show_rownames=T,
         fontsize=7,
         fontsize_row=7,
         fontsize_col=7)
dev.off()

data=melt(rt, id.vars=c("Cluster"))
colnames(data)=c("Cluster", "Gene", "Expression")

p=ggboxplot(data, x="Gene", y="Expression", color = "Cluster",
            xlab="",
            ylab="Gene expression",
            legend.title="Cluster",
            palette = crgCluCol,
            width=0.8,
            add="point")
p=p+rotate_x_text(60)
p1=p+stat_compare_means(aes(group=Cluster),
                        symnum.args=list(cutpoints = c(0, 0.001, 0.01, 0.05, 1), symbols = c("***", "**", "*", " ")),
                        label = "p.signif")

pdf(file="boxplot.pdf", width=7, height=5)
print(p1)
dev.off()

#if (!requireNamespace("BiocManager", quietly = TRUE))
#    install.packages("BiocManager")
#BiocManager::install("limma")

#install.packages("ggplot2")


library(limma)
library(ggplot2)

clusterFile="cluster.txt"      

rt=read.table(clusterFile, header=T, sep="\t", check.names=F, row.names=1)
data=rt[,1:(ncol(rt)-1),drop=F]
Cluster=as.vector(rt[,ncol(rt)])

data.pca=prcomp(data)
pcaPredict=predict(data.pca)
PCA=data.frame(PC1=pcaPredict[,1], PC2=pcaPredict[,2], Cluster=Cluster)
PCA.mean=aggregate(PCA[,1:2], list(Cluster=PCA$Cluster), mean)


bioCol=c("#0066FF","#FF0000","#FF9900","#6E568C","#7CC767","#223D6C","#D20A13","#FFD121","#088247","#11AA4D")
crgCluCol=bioCol[1:length(levels(factor(Cluster)))]


veganCovEllipse<-function (cov, center = c(0, 0), scale = 1, npoints = 100) {
  theta <- (0:npoints) * 2 * pi/npoints
  Circle <- cbind(cos(theta), sin(theta))
  t(center + scale * t(Circle %*% chol(cov)))
}
df_ell <- data.frame()
for(g in levels(factor(PCA$Cluster))){
  df_ell <- rbind(df_ell, cbind(as.data.frame(with(PCA[PCA$Cluster==g,],
                                                   veganCovEllipse(cov.wt(cbind(PC1,PC2),
                                                                          wt=rep(1/length(PC1),length(PC1)))$cov,
                                                                   center=c(mean(PC1),mean(PC2))))), Cluster=g))
}

pdf(file="PCA.pdf", width=6.5, height=5)
ggplot(data = PCA, aes(PC1, PC2)) + geom_point(aes(color = Cluster)) +
  scale_colour_manual(name="Cluster", values =crgCluCol)+
  theme_bw()+
  theme(plot.margin=unit(rep(1.5,4),'lines'))+
  geom_path(data=df_ell, aes(x=PC1, y=PC2, colour=Cluster), size=1, linetype=2)+
  annotate("text",x=PCA.mean$PC1, y=PCA.mean$PC2, label=PCA.mean$Cluster, cex=7)+
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())
dev.off()

#if (!requireNamespace("BiocManager", quietly = TRUE))
#    install.packages("BiocManager")
#BiocManager::install("limma")

#install.packages("reshape2")
#install.packages("ggpubr")


library(limma)
library(reshape2)
library(ggpubr)

clusterFile="cluster.txt"          
immFile="CIBERSORT-Results.txt"     


immune=read.table(immFile, header=T, sep="\t", check.names=F, row.names=1)


group=gsub("(.*)\\_(.*)", "\\2", row.names(immune))
data=immune[group=="Treat",,drop=F]


Cluster=read.table(clusterFile, header=T, sep="\t", check.names=F, row.names=1)
sameSample=intersect(row.names(data), row.names(Cluster))
rt=cbind(data[sameSample,,drop=F], Cluster[sameSample,"Cluster",drop=F])
rt=rt[order(rt$Cluster, decreasing=F),]
conNum=nrow(rt[rt$Cluster=="C1",])
treatNum=nrow(rt[rt$Cluster=="C2",])

data=t(rt[,-ncol(rt)])
pdf(file="barplot.pdf", width=14.5, height=8)
col=rainbow(nrow(data), s=0.7, v=0.7)
par(las=1,mar=c(8,5,4,16),mgp=c(3,0.1,0),cex.axis=1.5)
a1=barplot(data, col=col, xaxt="n", yaxt="n", ylab="Relative Percent", cex.lab=1.8)
a2=axis(2,tick=F,labels=F)
axis(2,a2,paste0(a2*100,"%"))
par(srt=0,xpd=T)
rect(xleft = a1[1]-0.5, ybottom = -0.01, xright = a1[conNum]+0.5, ytop = -0.06,col="green")
text(a1[conNum]/2,-0.035,"C1",cex=2)
rect(xleft = a1[conNum]+0.5, ybottom = -0.01, xright =a1[length(a1)]+0.5 , ytop = -0.06,col="red")
text((a1[length(a1)]+a1[conNum])/2,-0.035,"C2",cex=2)
ytick2 = cumsum(data[,ncol(data)])
ytick1 = c(0,ytick2[-length(ytick2)])
legend(par('usr')[2]*0.98,par('usr')[4],legend=rownames(data),col=col,pch=15,bty="n",cex=1.3)
dev.off()


data=rt
data=melt(data, id.vars=c("Cluster"))
colnames(data)=c("Cluster", "Immune", "Expression")

group=levels(factor(data$Cluster))
bioCol=c("#0066FF","#FF0000","#6E568C","#7CC767","#223D6C","#D20A13","#FFD121","#088247","#11AA4D")
bioCol=bioCol[1:length(group)]
boxplot=ggboxplot(data, x="Immune", y="Expression", color="Cluster",
                  xlab="",
                  ylab="Fraction",
                  legend.title="Cluster",
                  add="point",
                  width=0.8,
                  palette=bioCol)+
  rotate_x_text(50)+
  stat_compare_means(aes(group=Cluster),symnum.args=list(cutpoints=c(0, 0.001, 0.01, 0.05, 1), symbols=c("***", "**", "*", "")), label="p.signif")

pdf(file="immune.diff.pdf", width=8, height=6)
print(boxplot)
dev.off()

#if (!requireNamespace("BiocManager", quietly = TRUE))
#    install.packages("BiocManager")
#BiocManager::install("limma")
#BiocManager::install("GSEABase")
#BiocManager::install("GSVA")

#install.packages("ggpubr")


library(reshape2)
library(ggpubr)
library(limma)
library(GSEABase)
library(GSVA)

expFile="normalize.txt"             
clusterFile="cluster.txt"            
gmtFile="c2.cp.kegg.symbols.gmt"     


rt=read.table(expFile, header=T, sep="\t", check.names=F)
rt=as.matrix(rt)
rownames(rt)=rt[,1]
exp=rt[,2:ncol(rt)]
dimnames=list(rownames(exp),colnames(exp))
data=matrix(as.numeric(as.matrix(exp)),nrow=nrow(exp),dimnames=dimnames)
data=avereps(data)


group=gsub("(.*)\\_(.*)", "\\2", colnames(data))
data=data[,group=="Treat",drop=F]


geneSets=getGmt(gmtFile, geneIdType=SymbolIdentifier())


ssgseaScore=gsva(data, geneSets, method='gsva')

normalize=function(x){
  return((x-min(x))/(max(x)-min(x)))}
ssgseaScore=normalize(ssgseaScore)


cluster=read.table(clusterFile, header=T, sep="\t", check.names=F, row.names=1)
nameC1=row.names(cluster[cluster$Cluster=="C1",,drop=F])
nameC2=row.names(cluster[cluster$Cluster=="C2",,drop=F])
dataC1=ssgseaScore[,nameC1,drop=F]
dataC2=ssgseaScore[,nameC2,drop=F]
conNum=ncol(dataC1)
treatNum=ncol(dataC2)
data=cbind(dataC1, dataC2)
Type=c(rep("C1",conNum), rep("C2",treatNum))


outTab=data.frame()
for(i in row.names(data)){
  test=t.test(data[i,] ~ Type)
  pvalue=test$p.value
  t=test$statistic
  if(pvalue<0.05){
    Sig=ifelse(pvalue>0.05, "Not", ifelse(t>0,"Up","Down"))
    outTab=rbind(outTab, cbind(Pathway=i, t, pvalue, Sig))
  }
}


termNum=10  
outTab=outTab[order(outTab$t),]
outTab=outTab[c(1:termNum,(nrow(outTab)-termNum):nrow(outTab)),]
pdf(file="barplot.pdf", width=9, height=6)
outTab$t=as.numeric(outTab$t)
outTab$Sig=factor(outTab$Sig, levels=c("Down", "Up"))
gg1=ggbarplot(outTab, x="Pathway", y="t", fill = "Sig", color = "white",
              palette=c("blue3", "red3"), sort.val = "asc", sort.by.groups = T,
              rotate=TRUE, legend="right", title="",
              xlab="Term", ylab="t value of GSVA score, C2 vs C1",  legend.title="Group", x.text.angle=60)
print(gg1)
dev.off()

#if (!requireNamespace("BiocManager", quietly = TRUE))
#    install.packages("BiocManager")
#BiocManager::install(c("GO.db", "preprocessCore", "impute","limma"))

#install.packages(c("gplots", "matrixStats", "Hmisc", "foreach", "doParallel", "fastcluster", "dynamicTreeCut", "survival")) 
#install.packages("WGCNA")


library(limma)
library(gplots)
library(WGCNA)

expFile="normalize.txt"     


rt=read.table(expFile, header=T, sep="\t", check.names=F)
rt=as.matrix(rt)
rownames(rt)=rt[,1]
exp=rt[,2:ncol(rt)]
dimnames=list(rownames(exp),colnames(exp))
data=matrix(as.numeric(as.matrix(exp)),nrow=nrow(exp),dimnames=dimnames)
data=avereps(data)

selectGenes=names(tail(sort(apply(data,1,sd)), n=round(nrow(data)*0.25)))
data=data[selectGenes,]


Type=gsub("(.*)\\_(.*)", "\\2", colnames(data))
conCount=length(Type[Type=="Control"])
treatCount=length(Type[Type=="Treat"])
datExpr0=t(data)

gsg = goodSamplesGenes(datExpr0, verbose = 3)
if (!gsg$allOK){
  # Optionally, print the gene and sample names that were removed:
  if (sum(!gsg$goodGenes)>0)
    printFlush(paste("Removing genes:", paste(names(datExpr0)[!gsg$goodGenes], collapse = ", ")))
  if (sum(!gsg$goodSamples)>0)
    printFlush(paste("Removing samples:", paste(rownames(datExpr0)[!gsg$goodSamples], collapse = ", ")))
  # Remove the offending genes and samples from the data:
  datExpr0 = datExpr0[gsg$goodSamples, gsg$goodGenes]
}


sampleTree = hclust(dist(datExpr0), method = "average")
pdf(file = "01.sample_cluster.pdf", width = 12, height = 9)
par(cex = 0.6)
par(mar = c(0,4,2,0))
plot(sampleTree, main = "Sample clustering to detect outliers", sub="", xlab="", cex.lab = 1.5, cex.axis = 1.5, cex.main = 2)

abline(h = 20000, col="red")
dev.off()


clust=cutreeStatic(sampleTree, cutHeight=20000, minSize=10)
table(clust)
keepSamples=(clust==1)
datExpr0=datExpr0[keepSamples,]



traitData=data.frame(Con=c(rep(1,conCount),rep(0,treatCount)),
                     Treat=c(rep(0,conCount),rep(1,treatCount)))
row.names(traitData)=colnames(data)
fpkmSamples=rownames(datExpr0)
traitSamples=rownames(traitData)
sameSample=intersect(fpkmSamples,traitSamples)
datExpr0=datExpr0[sameSample,]
datTraits=traitData[sameSample,]


sampleTree2 = hclust(dist(datExpr0), method="average")
traitColors = numbers2colors(datTraits, signed = FALSE)
pdf(file="02.sample_heatmap.pdf", width=12, height=12)
plotDendroAndColors(sampleTree2, traitColors,
                    groupLabels = names(datTraits),
                    main = "Sample dendrogram and trait heatmap")
dev.off()


enableWGCNAThreads()  
powers = c(1:20)       
sft = pickSoftThreshold(datExpr0, powerVector = powers, verbose = 5)
pdf(file="03.scale_independence.pdf",width=9,height=5)
par(mfrow = c(1,2))
cex1 = 0.9

plot(sft$fitIndices[,1], -sign(sft$fitIndices[,3])*sft$fitIndices[,2],
     xlab="Soft Threshold (power)",ylab="Scale Free Topology Model Fit,signed R^2",type="n",
     main = paste("Scale independence"));
text(sft$fitIndices[,1], -sign(sft$fitIndices[,3])*sft$fitIndices[,2],
     labels=powers,cex=cex1,col="red");
abline(h=0.90,col="red") #?????޸?

plot(sft$fitIndices[,1], sft$fitIndices[,5],
     xlab="Soft Threshold (power)",ylab="Mean Connectivity", type="n",
     main = paste("Mean connectivity"))
text(sft$fitIndices[,1], sft$fitIndices[,5], labels=powers, cex=cex1,col="red")
dev.off()


sft
softPower =sft$powerEstimate     
adjacency = adjacency(datExpr0, power = softPower)
softPower



TOM = TOMsimilarity(adjacency)
dissTOM = 1-TOM


geneTree = hclust(as.dist(dissTOM), method = "average");
pdf(file="04.gene_clustering.pdf",width=12,height=9)
plot(geneTree, xlab="", sub="", main = "Gene clustering on TOM-based dissimilarity",
     labels = FALSE, hang = 0.04)
dev.off()


?
minModuleSize = 100    
dynamicMods = cutreeDynamic(dendro = geneTree, distM = dissTOM,
                            deepSplit = 2, pamRespectsDendro = FALSE,
                            minClusterSize = minModuleSize);
table(dynamicMods)
dynamicColors = labels2colors(dynamicMods)
table(dynamicColors)
pdf(file="05.Dynamic_Tree.pdf",width=8,height=6)
plotDendroAndColors(geneTree, dynamicColors, "Dynamic Tree Cut",
                    dendroLabels = FALSE, hang = 0.03,
                    addGuide = TRUE, guideHang = 0.05,
                    main = "Gene dendrogram and module colors")
dev.off()



MEList = moduleEigengenes(datExpr0, colors = dynamicColors)
MEs = MEList$eigengenes
MEDiss = 1-cor(MEs);
METree = hclust(as.dist(MEDiss), method = "average")
pdf(file="06.Clustering_module.pdf",width=7,height=6)
plot(METree, main = "Clustering of module eigengenes",
     xlab = "", sub = "")
dev.off()


moduleColors=dynamicColors
nGenes = ncol(datExpr0)
nSamples = nrow(datExpr0)
select = sample(nGenes, size=1000)      
selectTOM = dissTOM[select, select];
selectTree = hclust(as.dist(selectTOM), method="average")
selectColors = moduleColors[select]
#sizeGrWindow(9,9)
plotDiss=selectTOM^softPower
diag(plotDiss)=NA
myheatcol = colorpanel(250, "red", "orange", "lemonchiffon")  
pdf(file="07.TOMplot.pdf", width=7, height=7)
TOMplot(plotDiss, selectTree, selectColors, main = "Network heatmap plot, selected genes", col=myheatcol)
dev.off()


moduleTraitCor = cor(MEs, datTraits, use = "p")
moduleTraitPvalue = corPvalueStudent(moduleTraitCor, nSamples)
pdf(file="08.Module_trait.pdf", width=6.5, height=5.5)
textMatrix = paste(signif(moduleTraitCor, 2), "\n(",
                   signif(moduleTraitPvalue, 1), ")", sep = "")
dim(textMatrix) = dim(moduleTraitCor)
par(mar = c(3.5, 8, 3, 3))
labeledHeatmap(Matrix = moduleTraitCor,
               xLabels = names(datTraits),
               yLabels = names(MEs),
               ySymbols = names(MEs),
               colorLabels = FALSE,
               colors = blueWhiteRed(50),
               textMatrix = textMatrix,
               setStdMargins = FALSE,
               cex.text = 0.7,
               zlim = c(-1,1),
               main = paste("Module-trait relationships"))
dev.off()
modNames = substring(names(MEs), 3)
geneModuleMembership = as.data.frame(cor(datExpr0, MEs, use = "p"))
MMPvalue = as.data.frame(corPvalueStudent(as.matrix(geneModuleMembership), nSamples))
names(geneModuleMembership) = paste("MM", modNames, sep="")
names(MMPvalue) = paste("p.MM", modNames, sep="")
traitNames=names(datTraits)
geneTraitSignificance = as.data.frame(cor(datExpr0, datTraits, use = "p"))
GSPvalue = as.data.frame(corPvalueStudent(as.matrix(geneTraitSignificance), nSamples))
names(geneTraitSignificance) = paste("GS.", traitNames, sep="")
names(GSPvalue) = paste("p.GS.", traitNames, sep="")


trait="Treat"
traitColumn=match(trait,traitNames)  
for (module in modNames){
  column = match(module, modNames)
  moduleGenes = moduleColors==module
  if (nrow(geneModuleMembership[moduleGenes,]) > 1){
    outPdf=paste("09.", trait, "_", module,".pdf",sep="")
    pdf(file=outPdf,width=7,height=7)
    par(mfrow = c(1,1))
    verboseScatterplot(abs(geneModuleMembership[moduleGenes, column]),
                       abs(geneTraitSignificance[moduleGenes, traitColumn]),
                       xlab = paste("Module Membership in", module, "module"),
                       ylab = paste("Gene significance for ",trait),
                       main = paste("Module membership vs. gene significance\n"),
                       cex.main = 1.2, cex.lab = 1.2, cex.axis = 1.2, col = module)
    abline(v=0.8,h=0.5,col="red")
    dev.off()
  }
}


probes = colnames(datExpr0)
geneInfo0 = data.frame(probes= probes,
                       moduleColor = moduleColors)
for (Tra in 1:ncol(geneTraitSignificance))
{
  oldNames = names(geneInfo0)
  geneInfo0 = data.frame(geneInfo0, geneTraitSignificance[,Tra],
                         GSPvalue[, Tra])
  names(geneInfo0) = c(oldNames,names(geneTraitSignificance)[Tra],
                       names(GSPvalue)[Tra])
}

for (mod in 1:ncol(geneModuleMembership))
{
  oldNames = names(geneInfo0)
  geneInfo0 = data.frame(geneInfo0, geneModuleMembership[,mod],
                         MMPvalue[, mod])
  names(geneInfo0) = c(oldNames,names(geneModuleMembership)[mod],
                       names(MMPvalue)[mod])
}
geneOrder =order(geneInfo0$moduleColor)
geneInfo = geneInfo0[geneOrder, ]
write.table(geneInfo, file = "GS_MM.xls",sep="\t",row.names=F)



for (mod in 1:nrow(table(moduleColors))){  
  modules = names(table(moduleColors))[mod]
  probes = colnames(datExpr0)
  inModule = (moduleColors == modules)
  modGenes = probes[inModule]
  write.table(modGenes, file =paste0("module_",modules,".txt"),sep="\t",row.names=F,col.names=F,quote=F)
}


geneSigFilter=0.5        
moduleSigFilter=0.8       
datMM=cbind(geneModuleMembership, geneTraitSignificance)
datMM=datMM[abs(datMM[,ncol(datMM)])>geneSigFilter,]
for(mmi in colnames(datMM)[1:(ncol(datMM)-2)]){
  dataMM2=datMM[abs(datMM[,mmi])>moduleSigFilter,]
  write.table(row.names(dataMM2), file =paste0("hubGenes_",mmi,".txt"),sep="\t",row.names=F,col.names=F,quote=F)
}

#if (!requireNamespace("BiocManager", quietly = TRUE))
#    install.packages("BiocManager")
#BiocManager::install(c("GO.db", "preprocessCore", "impute","limma"))

#install.packages(c("gplots", "matrixStats", "Hmisc", "foreach", "doParallel", "fastcluster", "dynamicTreeCut", "survival")) 
#install.packages("WGCNA")



library(limma)
library(gplots)
library(WGCNA)

expFile="normalize.txt"       
clusterFile="cluster.txt"    



rt=read.table(expFile, header=T, sep="\t", check.names=F)
rt=as.matrix(rt)
rownames(rt)=rt[,1]
exp=rt[,2:ncol(rt)]
dimnames=list(rownames(exp),colnames(exp))
data=matrix(as.numeric(as.matrix(exp)),nrow=nrow(exp),dimnames=dimnames)
data=avereps(data)
selectGenes=names(tail(sort(apply(data,1,sd)), n=round(nrow(data)*0.25)))
data=data[selectGenes,]


cluster=read.table(clusterFile, header=T, sep="\t", check.names=F, row.names=1)
nameC1=row.names(cluster[cluster$Cluster=="C1",,drop=F])
nameC2=row.names(cluster[cluster$Cluster=="C2",,drop=F])
dataC1=data[,nameC1,drop=F]
dataC2=data[,nameC2,drop=F]
conCount=ncol(dataC1)
treatCount=ncol(dataC2)
data=cbind(dataC1, dataC2)
datExpr0=t(data)


gsg = goodSamplesGenes(datExpr0, verbose = 3)
if (!gsg$allOK){
  # Optionally, print the gene and sample names that were removed:
  if (sum(!gsg$goodGenes)>0)
    printFlush(paste("Removing genes:", paste(names(datExpr0)[!gsg$goodGenes], collapse = ", ")))
  if (sum(!gsg$goodSamples)>0)
    printFlush(paste("Removing samples:", paste(rownames(datExpr0)[!gsg$goodSamples], collapse = ", ")))
  # Remove the offending genes and samples from the data:
  datExpr0 = datExpr0[gsg$goodSamples, gsg$goodGenes]
}


sampleTree = hclust(dist(datExpr0), method = "average")
pdf(file = "cluster01.sample_cluster.pdf", width = 12, height = 9)
par(cex = 0.6)
par(mar = c(0,4,2,0))
plot(sampleTree, main = "Sample clustering to detect outliers", sub="", xlab="", cex.lab = 1.5, cex.axis = 1.5, cex.main = 2)

abline(h = 20000, col = "red")
dev.off()


clust=cutreeStatic(sampleTree, cutHeight = 20000, minSize = 10)
table(clust)
keepSamples=(clust==1)
datExpr0=datExpr0[keepSamples, ]


traitData=data.frame(C1=c(rep(1,conCount),rep(0,treatCount)),
                     C2=c(rep(0,conCount),rep(1,treatCount)))
row.names(traitData)=colnames(data)
fpkmSamples=rownames(datExpr0)
traitSamples=rownames(traitData)
sameSample=intersect(fpkmSamples,traitSamples)
datExpr0=datExpr0[sameSample,]
datTraits=traitData[sameSample,]



sampleTree2 = hclust(dist(datExpr0), method = "average")
traitColors = numbers2colors(datTraits, signed = FALSE)
pdf(file="cluster02.sample_heatmap.pdf",width=12,height=12)
plotDendroAndColors(sampleTree2, traitColors,
                    groupLabels = names(datTraits),
                    main = "Sample dendrogram and trait heatmap")
dev.off()


enableWGCNAThreads() 
powers = c(1:20)   
sft = pickSoftThreshold(datExpr0, powerVector = powers, verbose = 5)
pdf(file="cluster03.scale_independence.pdf",width=9,height=5)
par(mfrow = c(1,2))
cex1 = 0.9

plot(sft$fitIndices[,1], -sign(sft$fitIndices[,3])*sft$fitIndices[,2],
     xlab="Soft Threshold (power)",ylab="Scale Free Topology Model Fit,signed R^2",type="n",
     main = paste("Scale independence"));
text(sft$fitIndices[,1], -sign(sft$fitIndices[,3])*sft$fitIndices[,2],
     labels=powers,cex=cex1,col="red");
abline(h=0.90,col="red") #?????޸?

plot(sft$fitIndices[,1], sft$fitIndices[,5],
     xlab="Soft Threshold (power)",ylab="Mean Connectivity", type="n",
     main = paste("Mean connectivity"))
text(sft$fitIndices[,1], sft$fitIndices[,5], labels=powers, cex=cex1,col="red")
dev.off()


sft 
softPower =sft$powerEstimate
adjacency = adjacency(datExpr0, power = softPower)
softPower



TOM = TOMsimilarity(adjacency)
dissTOM = 1-TOM


geneTree = hclust(as.dist(dissTOM), method = "average");
pdf(file="cluster04.gene_clustering.pdf",width=12,height=9)
plot(geneTree, xlab="", sub="", main = "Gene clustering on TOM-based dissimilarity",
     labels = FALSE, hang = 0.04)
dev.off()


minModuleSize = 100      #ģ????????Ŀ
dynamicMods = cutreeDynamic(dendro = geneTree, distM = dissTOM,
                            deepSplit = 2, pamRespectsDendro = FALSE,
                            minClusterSize = minModuleSize);
table(dynamicMods)
dynamicColors = labels2colors(dynamicMods)
table(dynamicColors)
pdf(file="cluster05.Dynamic_Tree.pdf",width=8,height=6)
plotDendroAndColors(geneTree, dynamicColors, "Dynamic Tree Cut",
                    dendroLabels = FALSE, hang = 0.03,
                    addGuide = TRUE, guideHang = 0.05,
                    main = "Gene dendrogram and module colors")
dev.off()



MEList = moduleEigengenes(datExpr0, colors = dynamicColors)
MEs = MEList$eigengenes
MEDiss = 1-cor(MEs);
METree = hclust(as.dist(MEDiss), method = "average")
pdf(file="cluster06.Clustering_module.pdf",width=7,height=6)
plot(METree, main = "Clustering of module eigengenes",
     xlab = "", sub = "")
dev.off()


moduleColors=dynamicColors
nGenes = ncol(datExpr0)
nSamples = nrow(datExpr0)
select = sample(nGenes, size=1000)
selectTOM = dissTOM[select, select];
selectTree = hclust(as.dist(selectTOM), method="average")
selectColors = moduleColors[select]
#sizeGrWindow(9,9)
plotDiss=selectTOM^softPower
diag(plotDiss)=NA
myheatcol = colorpanel(250, "red", "orange", "lemonchiffon")    #??????ͼ??ɫ(??ɫ??????
pdf(file="cluster07.TOMplot.pdf", width=7, height=7)
TOMplot(plotDiss, selectTree, selectColors, main = "Network heatmap plot, selected genes", col=myheatcol)
dev.off()



moduleTraitCor = cor(MEs, datTraits, use = "p")
moduleTraitPvalue = corPvalueStudent(moduleTraitCor, nSamples)
pdf(file="cluster08.Module_trait.pdf", width=6.5, height=5.5)
textMatrix = paste(signif(moduleTraitCor, 2), "\n(",
                   signif(moduleTraitPvalue, 1), ")", sep = "")
dim(textMatrix) = dim(moduleTraitCor)
par(mar = c(3.5, 8, 3, 3))
labeledHeatmap(Matrix = moduleTraitCor,
               xLabels = names(datTraits),
               yLabels = names(MEs),
               ySymbols = names(MEs),
               colorLabels = FALSE,
               colors = blueWhiteRed(50),
               textMatrix = textMatrix,
               setStdMargins = FALSE,
               cex.text = 0.7,
               zlim = c(-1,1),
               main = paste("Module-trait relationships"))
dev.off()



modNames = substring(names(MEs), 3)
geneModuleMembership = as.data.frame(cor(datExpr0, MEs, use = "p"))
MMPvalue = as.data.frame(corPvalueStudent(as.matrix(geneModuleMembership), nSamples))
names(geneModuleMembership) = paste("MM", modNames, sep="")
names(MMPvalue) = paste("p.MM", modNames, sep="")
traitNames=names(datTraits)
geneTraitSignificance = as.data.frame(cor(datExpr0, datTraits, use = "p"))
GSPvalue = as.data.frame(corPvalueStudent(as.matrix(geneTraitSignificance), nSamples))
names(geneTraitSignificance) = paste("GS.", traitNames, sep="")
names(GSPvalue) = paste("p.GS.", traitNames, sep="")


trait="C2"
traitColumn=match(trait,traitNames)  
for (module in modNames){
  column = match(module, modNames)
  moduleGenes = moduleColors==module
  if (nrow(geneModuleMembership[moduleGenes,]) > 1){
    outPdf=paste("cluster09.", trait, "_", module,".pdf",sep="")
    pdf(file=outPdf,width=7,height=7)
    par(mfrow = c(1,1))
    verboseScatterplot(abs(geneModuleMembership[moduleGenes, column]),
                       abs(geneTraitSignificance[moduleGenes, traitColumn]),
                       xlab = paste("Module Membership in", module, "module"),
                       ylab = paste("Gene significance for ",trait),
                       main = paste("Module membership vs. gene significance\n"),
                       cex.main = 1.2, cex.lab = 1.2, cex.axis = 1.2, col = module)
    abline(v=0.8,h=0.5,col="red")
    dev.off()
  }
}



probes = colnames(datExpr0)
geneInfo0 = data.frame(probes= probes,
                       moduleColor = moduleColors)
for (Tra in 1:ncol(geneTraitSignificance))
{
  oldNames = names(geneInfo0)
  geneInfo0 = data.frame(geneInfo0, geneTraitSignificance[,Tra],
                         GSPvalue[, Tra])
  names(geneInfo0) = c(oldNames,names(geneTraitSignificance)[Tra],
                       names(GSPvalue)[Tra])
}

for (mod in 1:ncol(geneModuleMembership))
{
  oldNames = names(geneInfo0)
  geneInfo0 = data.frame(geneInfo0, geneModuleMembership[,mod],
                         MMPvalue[, mod])
  names(geneInfo0) = c(oldNames,names(geneModuleMembership)[mod],
                       names(MMPvalue)[mod])
}
geneOrder =order(geneInfo0$moduleColor)
geneInfo = geneInfo0[geneOrder, ]
write.table(geneInfo, file = "cluster.GS_MM.xls",sep="\t",row.names=F)



for (mod in 1:nrow(table(moduleColors))){  
  modules = names(table(moduleColors))[mod]
  probes = colnames(datExpr0)
  inModule = (moduleColors == modules)
  modGenes = probes[inModule]
  write.table(modGenes, file =paste0("cluster.module_",modules,".txt"),sep="\t",row.names=F,col.names=F,quote=F)
}

geneSigFilter=0.5         

moduleSigFilter=0.8       
datMM=cbind(geneModuleMembership, geneTraitSignificance)
datMM=datMM[abs(datMM[,ncol(datMM)])>geneSigFilter,]
for(mmi in colnames(datMM)[1:(ncol(datMM)-2)]){
  dataMM2=datMM[abs(datMM[,mmi])>moduleSigFilter,]
  write.table(row.names(dataMM2), file =paste0("cluster.hubGenes_",mmi,".txt"),sep="\t",row.names=F,col.names=F,quote=F)
}


#install.packages("VennDiagram")


library(VennDiagram)      
diseaseFile="hubGenes_MMturquoise.txt"            
clusterFile="cluster.hubGenes_MMturquoise.txt"         

geneList=list()

rt=read.table(diseaseFile, header=F, sep="\t", check.names=F)
geneNames=as.vector(rt[,1])              
geneNames=gsub("^ | $","",geneNames)     
uniqGene=unique(geneNames)               
geneList[["Disease WGCNA"]]=uniqGene     


rt=read.table(clusterFile, header=F, sep="\t", check.names=F)
geneNames=as.vector(rt[,1])    
geneNames=gsub("^ | $","",geneNames)     
uniqGene=unique(geneNames)               
geneList[["Cluster WGCNA"]]=uniqGene     

venn.plot=venn.diagram(geneList,filename=NULL,fill=c("cornflowerblue", "darkorchid1"),scaled=FALSE,cat.pos=c(-1,1),cat.col = c("cornflowerblue", "darkorchid1"),cat.cex=1)
pdf(file="venn.pdf", width=5, height=5)
grid.draw(venn.plot)
dev.off()


interGenes=Reduce(intersect,geneList)
write.table(file="interGenes.txt", interGenes, sep="\t", quote=F, col.names=F, row.names=F)

#install.packages("caret")
#install.packages("DALEX")
#install.packages("ggplot2")
#install.packages("randomForest")
#install.packages("kernlab")
#install.packages("pROC")
#install.packages("xgboost")



library(caret)
library(DALEX)
library(ggplot2)
library(randomForest)
library(kernlab)
library(xgboost)
library(pROC)

set.seed(123)      
inputFile="normalize.txt"    
geneFile="interGenes.txt"      


data=read.table(inputFile, header=T, sep="\t", check.names=F, row.names=1)


geneRT=read.table(geneFile, header=F, sep="\t", check.names=F)
data=data[as.vector(geneRT[,1]),]
row.names(data)=gsub("-", "_", row.names(data))

data=t(data)
group=gsub("(.*)\\_(.*)", "\\2", row.names(data))
data=as.data.frame(data)
data$Type=group


inTrain<-createDataPartition(y=data$Type, p=0.7, list=F)
train<-data[inTrain,]
test<-data[-inTrain,]


control=trainControl(method="repeatedcv", number=5, savePredictions=TRUE)
mod_rf = train(Type ~ ., data = train, method='rf', trControl = control)


mod_svm=train(Type ~., data = train, method = "svmRadial", prob.model=TRUE, trControl=control)

mod_xgb=train(Type ~., data = train, method = "xgbDART", trControl=control)


mod_glm=train(Type ~., data = train, method = "glm", family="binomial", trControl=control)



p_fun=function(object, newdata){
  predict(object, newdata=newdata, type="prob")[,2]
}
yTest=ifelse(test$Type=="Control", 0, 1)


explainer_rf=explain(mod_rf, label = "RF",
                     data = test, y = yTest,
                     predict_function = p_fun,
                     verbose = FALSE)
mp_rf=model_performance(explainer_rf)

explainer_svm=explain(mod_svm, label = "SVM",
                      data = test, y = yTest,
                      predict_function = p_fun,
                      verbose = FALSE)
mp_svm=model_performance(explainer_svm)

explainer_xgb=explain(mod_xgb, label = "XGB",
                      data = test, y = yTest,
                      predict_function = p_fun,
                      verbose = FALSE)
mp_xgb=model_performance(explainer_xgb)

explainer_glm=explain(mod_glm, label = "GLM",
                      data = test, y = yTest,
                      predict_function = p_fun,
                      verbose = FALSE)
mp_glm=model_performance(explainer_glm)


pdf(file="residual.pdf", width=6, height=6)
p1 <- plot(mp_rf, mp_svm, mp_xgb, mp_glm)
print(p1)
dev.off()


pdf(file="boxplot.pdf", width=6, height=6)
p2 <- plot(mp_rf, mp_svm, mp_xgb, mp_glm, geom = "boxplot")
print(p2)
dev.off()



pred1=predict(mod_rf, newdata=test, type="prob")
pred2=predict(mod_svm, newdata=test, type="prob")
pred3=predict(mod_xgb, newdata=test, type="prob")
pred4=predict(mod_glm, newdata=test, type="prob")
roc1=roc(yTest, as.numeric(pred1[,2]))
roc2=roc(yTest, as.numeric(pred2[,2]))
roc3=roc(yTest, as.numeric(pred3[,2]))
roc4=roc(yTest, as.numeric(pred4[,2]))
pdf(file="ROC.pdf", width=5, height=5)
plot(roc1, print.auc=F, legacy.axes=T, main="", col="red")
plot(roc2, print.auc=F, legacy.axes=T, main="", col="blue", add=T)
plot(roc3, print.auc=F, legacy.axes=T, main="", col="green", add=T)
plot(roc4, print.auc=F, legacy.axes=T, main="", col="yellow", add=T)
legend('bottomright',
       c(paste0('RF: ',sprintf("%.03f",roc1$auc)),
         paste0('SVM: ',sprintf("%.03f",roc2$auc)),
         paste0('XGB: ',sprintf("%.03f",roc3$auc)),
         paste0('GLM: ',sprintf("%.03f",roc4$auc))),
       col=c("red","blue","green","yellow"), lwd=2, bty = 'n')
dev.off()


importance_rf<-variable_importance(
  explainer_rf,
  loss_function = loss_root_mean_square
)
importance_svm<-variable_importance(
  explainer_svm,
  loss_function = loss_root_mean_square
)
importance_glm<-variable_importance(
  explainer_glm,
  loss_function = loss_root_mean_square
)
importance_xgb<-variable_importance(
  explainer_xgb,
  loss_function = loss_root_mean_square
)

pdf(file="importance.pdf", width=7, height=10)
plot(importance_rf[c(1,(ncol(data)-8):(ncol(data)+1)),],
     importance_svm[c(1,(ncol(data)-8):(ncol(data)+1)),],
     importance_xgb[c(1,(ncol(data)-8):(ncol(data)+1)),],
     importance_glm[c(1,(ncol(data)-8):(ncol(data)+1)),])
dev.off()

geneNum=5 
write.table(importance_rf[(ncol(data)-geneNum+2):(ncol(data)+1),], file="importanceGene.RF.txt", sep="\t", quote=F, row.names=F)
write.table(importance_svm[(ncol(data)-geneNum+2):(ncol(data)+1),], file="importanceGene.SVM.txt", sep="\t", quote=F, row.names=F)
write.table(importance_xgb[(ncol(data)-geneNum+2):(ncol(data)+1),], file="importanceGene.XGB.txt", sep="\t", quote=F, row.names=F)
write.table(importance_glm[(ncol(data)-geneNum+2):(ncol(data)+1),], file="importanceGene.GLM.txt", sep="\t", quote=F, row.names=F)


library(rms)
library(rmda)

inputFile="normalize.txt"             
geneFile=""     


data=read.table(inputFile, header=T, sep="\t", check.names=F, row.names=1)
row.names(data)=gsub("-", "_", row.names(data))


geneRT=read.table(geneFile, header=T, sep="\t", check.names=F)
data=data[as.vector(geneRT[,1]),]

data=t(data)
group=gsub("(.*)\\_(.*)", "\\2", row.names(data))
rt=cbind(as.data.frame(data), Type=group)
paste(colnames(data), collapse="+")


ddist=datadist(rt)
options(datadist="ddist")


lrmModel=lrm(Type~ ENC1+AUH+UBE2E4P+R3HDM1+ITPKB, data=rt, x=T, y=T)
nomo=nomogram(lrmModel, fun=plogis,
              fun.at=c(0.0001,0.1,0.3,0.5,0.7,0.9,0.99),
              lp=F, funlabel="Risk of Disease")

pdf("Nomo.pdf", width=8, height=6)
plot(nomo)
dev.off()


cali=calibrate(lrmModel, method="boot", B=1000)
pdf("Calibration.pdf", width=5.5, height=5.5)
plot(cali,
     xlab="Predicted probability",
     ylab="Actual probability", sub=F)
dev.off()

rt$Type=ifelse(rt$Type=="Control", 0, 1)
dc=decision_curve(Type ~ ENC1+AUH+UBE2E4P+R3HDM1+ITPKB, data=rt, 
                  family = binomial(link ='logit'),
                  thresholds= seq(0,1,by = 0.01),
                  confidence.intervals = 0.95)

pdf(file="DCA.pdf", width=5.5, height=5.5)
plot_decision_curve(dc,
                    curve.names="Model",
                    xlab="Threshold probability",
                    cost.benefit.axis=T,
                    col="red",
                    confidence.intervals=FALSE,
                    standardize=FALSE)
dev.off()


#if (!requireNamespace("BiocManager", quietly = TRUE))
#    install.packages("BiocManager")
#BiocManager::install("limma")


library(limma)             
expFile="GSE122063geneMatrix.txt"     
conFile="GSE122063s1.txt"            
treatFile="GSE122063s2.txt"        


rt=read.table(expFile, header=T, sep="\t", check.names=F)
rt=as.matrix(rt)
rownames(rt)=rt[,1]
exp=rt[,2:ncol(rt)]
dimnames=list(rownames(exp),colnames(exp))
data=matrix(as.numeric(as.matrix(exp)),nrow=nrow(exp),dimnames=dimnames)
data=avereps(data)


s1=read.table(conFile, header=F, sep="\t", check.names=F)
sampleName1=as.vector(s1[,1])
conData=data[,sampleName1]

s2=read.table(treatFile, header=F, sep="\t", check.names=F)
sampleName2=as.vector(s2[,1])
treatData=data[,sampleName2]


rt=cbind(conData, treatData)

qx=as.numeric(quantile(rt, c(0, 0.25, 0.5, 0.75, 0.99, 1.0), na.rm=T))
LogC=( (qx[5]>100) || ( (qx[6]-qx[1])>50 && qx[2]>0) )
if(LogC){
  rt[rt<0]=0
  rt=log2(rt+1)}
data=normalizeBetweenArrays(rt)

conNum=ncol(conData)
treatNum=ncol(treatData)
Type=c(rep("Control",conNum),rep("Treat",treatNum))
outData=rbind(id=paste0(colnames(data),"_",Type),data)
write.table(outData, file="test.normalize.txt", sep="\t", quote=F, col.names=F)


#install.packages("caret")
#install.packages("DALEX")
#install.packages("ggplot2")
#install.packages("randomForest")
#install.packages("kernlab")
#install.packages("pROC")
#install.packages("xgboost")


library(caret)
library(DALEX)
library(ggplot2)
library(randomForest)
library(kernlab)
library(xgboost)
library(pROC)

set.seed(123)     
inputFile="test.normalize.txt"       
geneFile="importanceGene.RF.txt"     


data=read.table(inputFile, header=T, sep="\t", check.names=F, row.names=1)
row.names(data)=gsub("-", "_", row.names(data))


geneRT=read.table(geneFile, header=T, sep="\t", check.names=F)
data=data[as.vector(geneRT[,1]),]


data=t(data)
group=gsub("(.*)\\_(.*)", "\\2", row.names(data))
data=as.data.frame(data)
data$Type=group


inTrain<-createDataPartition(y=data$Type, p=0.7, list=F)
train<-data[inTrain,]
test<-data[-inTrain,]


control=trainControl(method="repeatedcv", number=5, savePredictions=TRUE)
if(geneFile=="importanceGene.RF.txt"){

  model=train(Type ~ ., data = train, method='rf', trControl = control)
}else if(geneFile=="importanceGene.SVM.txt"){

  model=train(Type ~., data = train, method = "svmRadial", prob.model=TRUE, trControl=control)
}else if(geneFile=="importanceGene.XGB.txt"){

  model=train(Type ~., data = train, method = "xgbDART", trControl=control)
}else if(geneFile=="importanceGene.GLM.txt"){

  model=train(Type ~., data = train, method = "glm", family="binomial", trControl=control)
}


yTest=ifelse(test$Type=="Control", 0, 1)
pred1=predict(model, newdata=test, type="prob")
roc1=roc(yTest, as.numeric(pred1[,2]))
ci1=ci.auc(roc1, method="bootstrap")
ciVec=as.numeric(ci1)
pdf(file="ROC.pdf", width=5, height=5)
plot(roc1, print.auc=T, legacy.axes=T, main="", col="red")
text(0.39, 0.43, paste0("95% CI: ",sprintf("%.03f",ciVec[1]),"-",sprintf("%.03f",ciVec[3])), col="red")
dev.off()



#if (!requireNamespace("BiocManager", quietly = TRUE))
#    install.packages("BiocManager")
#BiocManager::install("limma")

#install.packages("ggplot2")
#install.packages("ggpubr")
#install.packages("ggExtra")


library(limma)
library(ggplot2)
library(ggpubr)
library(ggExtra)

inputFile="test.normalize.txt"         
geneFile="importanceGene.RF.txt"      
cliFile="clinical.txt"                 


data=read.table(inputFile, header=T, sep="\t", check.names=F, row.names=1)
row.names(data)=gsub("-", "_", row.names(data))


geneRT=read.table(geneFile, header=T, sep="\t", check.names=F)
data=data[as.vector(geneRT[,1]),]


group=sapply(strsplit(colnames(data),"\\_"), "[", 2)
data=data[,group=="Treat"]
colnames(data)=gsub("_Treat", "", colnames(data))

clinical=read.table(cliFile, header=T, sep="\t", check.names=F, row.names=1)
cliName=colnames(clinical)[1]
sameSample=intersect(colnames(data), row.names(clinical))
clinical=clinical[sameSample,,drop=F]
data=data[,sameSample,drop=F]


y=as.numeric(clinical[,cliName])
outTab=data.frame()
for(i in row.names(data)){
  x=as.numeric(data[i,])
  corT=cor.test(x, y, method = 'spearman')
  cor=corT$estimate
  pvalue=corT$p.value
  outTab=rbind(outTab, cbind(Gene=i, Clinical=cliName, cor, pvalue))

  df1=as.data.frame(cbind(x,y))
  p1=ggplot(df1, aes(x, y)) + 
    xlab(i)+ylab(cliName)+ 
    geom_point()+ geom_smooth(method="lm",formula = y ~ x) + theme_bw()+
    stat_cor(method = 'spearman', aes(x =x, y =y))

  pdf(file=paste0(cliName,"_",i,".pdf"), width=5, height=4.5)
  print(p2)
  dev.off()
}

write.table(file="corResult.txt",outTab,sep="\t",quote=F,row.names=F)



