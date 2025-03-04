# Return result from sData method and compare to expected
# Return result from svarLabels method and compare to expected
# Return result from dimLabels method and compare to expected


library(GeomxTools)
library(testthat)

datadir <- system.file("extdata", "DSP_NGS_Example_Data",
                       package="GeomxTools")
DCCFiles <- dir(datadir, pattern=".dcc$", full.names=TRUE)
PKCFiles <- unzip(zipfile = file.path(datadir,  "/pkcs.zip"))
SampleAnnotationFile <- file.path(datadir, "annotations.xlsx")

protocolDataColNames <- c("aoi",
                          "cell_line",
                          "roi_rep",
                          "pool_rep",
                          "slide_rep")

testData <-
  suppressWarnings(readNanoStringGeoMxSet(dccFiles = DCCFiles, # QuickBase: readNanoStringGeomxSet, need to change it
                                          pkcFiles = PKCFiles,
                                          phenoDataFile = SampleAnnotationFile,
                                          phenoDataSheet = "CW005",
                                          phenoDataDccColName = "Sample_ID",
                                          protocolDataColNames = protocolDataColNames,
                                          experimentDataColNames = c("panel")))


testData_agg <- aggregateCounts(testData)

DCCFiles <- DCCFiles[!basename(DCCFiles) %in% unique(sData(testData)$NTC_ID)]

# req 1: test that the rownames and column names in sData are correct:------
testthat::test_that("test that the rownames and column names in sData are correct", {
  expect_true(all(basename(DCCFiles) %in% rownames(sData(testData))))
  expect_true(all(c(names(testData@phenoData@data),
                    protocolDataColNames) %in% colnames(sData(testData))))
})




# req 2: test that the svarLabels method gives the correct results:------
testthat::test_that("test that the svarLabels method gives the correct results", {
  expect_true(all(svarLabels(testData) == colnames(sData(testData))))
})




# req 3: test that the dimLabels method gives the correct results:------
testthat::test_that("test that the dimLabels method gives the correct results", {
  expect_true(length(dimLabels(testData)) == 2)
  expect_true(all(paste0(sData(testData)[[dimLabels(testData)[2]]], ".dcc") == colnames(testData@assayData$exprs)))
  expect_true(all(testData@featureData@data[[dimLabels(testData)[1]]] == rownames(testData@assayData$exprs)))
})



# req 4: test that the design method gives the correct results:------
testthat::test_that("test that the design method gives the correct results", {
  expect_true(is.null(design(testData)))
})



# req 5: test that the featureType method gives the correct results:------
testthat::test_that("test that the featureType method gives the correct results", {
  expect_true(featureType(testData_agg) == "Target")
  expect_true(featureType(testData) == "Probe")
  expect_false(featureType(testData_agg) == featureType(testData))
})
