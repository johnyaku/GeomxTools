# Return colnames and rownames of testData@assayData$expr comparing to expected
# Return colnames and rownames of testData@phenoData@data comparing to expected
# Return colnames and rownames of testData@protocolData@data comparing to expected
# Return genes of testData@featureData@data comparing to expected
# Return testData@experimentData comparing to expected

library(GeomxTools)
library(testthat)
library(stringr)

datadir <- system.file("extdata", "DSP_NGS_Example_Data",
                       package="GeomxTools")
DCCFiles <- dir(datadir, pattern=".dcc$", full.names=TRUE)
PKCFiles <- unzip(zipfile = file.path(datadir,  "/pkcs.zip"))
SampleAnnotationFile <- file.path(datadir, "annotations.xlsx")

testData <-
  suppressWarnings(readNanoStringGeoMxSet(dccFiles = DCCFiles, # QuickBase: readNanoStringGeomxSet, need to change it.
                                          pkcFiles = PKCFiles,
                                          phenoDataFile = SampleAnnotationFile,
                                          phenoDataSheet = "CW005",
                                          phenoDataDccColName = "Sample_ID",
                                          protocolDataColNames = c("aoi",
                                                                   "cell_line",
                                                                   "roi_rep",
                                                                   "pool_rep",
                                                                   "slide_rep"),
                                          experimentDataColNames = c("panel")))

pkcFile <- readPKCFile(PKCFiles)

DCCFiles <- DCCFiles[!basename(DCCFiles) %in% unique(sData(testData)$NTC_ID)]


# req 1: test that the column names and the rownames of testData@assayData$exprs match those in DCC files and PKC Files respectively:------
testthat::test_that("test that the column names and the rownames of testData@assayData$exprs match those in DCC files and PKC Files respectively", {
  expect_true(all(basename(DCCFiles) %in% colnames(testData@assayData$exprs)))
  expect_true(all(unique(pkcFile$RTS_ID) %in% rownames(testData@assayData$exprs)))
})




# req 2: test that the column names and the rownames of testData@phenoData$data match those in DCC files and PKC Files respectively:------ 
testthat::test_that("test that the column names and the rownames of testData@phenoData$exprs match those in DCC files and PKC Files respectively", {
  phenoDataDccColName <- "Sample_ID"
  protocolDataColNames <- c("aoi",
                            "cell_line",
                            "roi_rep",
                            "pool_rep",
                            "slide_rep")
  experimentDataColNames <- c("panel")
  pheno_tab <- openxlsx::read.xlsx(SampleAnnotationFile, sheet = 'CW005')
  colnames(pheno_tab) <- str_replace_all(colnames(pheno_tab),'\\.',' ')
  expect_true(all(basename(DCCFiles) %in% rownames(testData@phenoData@data)))
  expect_true(all(colnames(pheno_tab) %in% c(names(testData@phenoData@data), # what is pheno_tab?
                                             phenoDataDccColName,
                                             protocolDataColNames,
                                             experimentDataColNames)))
})




# req 3: test that the column names and the rownames of testData@protocolData$data match those in DCC files and PKC Files respectively:------
testthat::test_that("test that the column names and the rownames of testData@protocolData$exprs match those in DCC files and PKC Files respectively", {
  protocolDataColNames <- c("aoi",
                            "cell_line",
                            "roi_rep",
                            "pool_rep",
                            "slide_rep")
  expect_true(all(basename(DCCFiles) %in% rownames(testData@protocolData@data)))
  expect_true(all(protocolDataColNames %in% names(testData@protocolData@data)))
})




# req 4: test that the genes in testData@featureData@data match those in PKC Files:------
testthat::test_that("test that the genes in testData@featureData$exprs match those in PKC Files", {
  expect_true(dim(testData@featureData@data)[1] == length(unique(pkcFile$RTS_ID))) # QuickBase: length(unique(pkcFile$Gene))
  expect_true(all(unique(pkcFile$RTS_ID) %in% testData@featureData@data$RTS_ID))
})



# req 5: test that the names in testData@experimentData@other are in correct format:------
testthat::test_that("test that the names in testData@experimentData@other are in correct format", {
  experimentDataColNames <- c("panel")
  experimentDataColNames <- c(experimentDataColNames, 
                              "PKCFileName",
                              "PKCFileVersion",
                              "PKCFileDate",
                              "AnalyteType",
                              "MinArea",
                              "MinNuclei")
  expect_true(all(experimentDataColNames %in% names(testData@experimentData@other))) 
})


#req 6: test that the counts in testData@assayData$exprs match those in DCC files
testthat::test_that("test that the counts of testData@assayData$exprs match those in DCC files", {
  correct <- TRUE
  i <- 1
  while(correct == TRUE & i < length(DCCFiles)){
    dccFile <- suppressWarnings(readDccFile(DCCFiles[i]))
    
    mtxCount <- testData@assayData$exprs[,basename(DCCFiles[i])]
    genes <- match(dccFile$Code_Summary$RTS_ID, names(mtxCount))
    
    correct <- all(mtxCount[genes] == dccFile$Code_Summary$Count) & all(mtxCount[!genes] == 0)
    
    i <- i+1
  }
  expect_true(correct)
})


