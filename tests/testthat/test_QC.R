# devtools::install_github("https://github.com/Nanostring-Biostats/GeomxTools/", ref="dev", force = TRUE, dependencies = FALSE)

library(NanoStringNCTools)
library(GeomxTools)
library(testthat)
library(EnvStats)
library(ggiraph)


testData <- readRDS(file= system.file("extdata","DSP_NGS_Example_Data", "demoData.rds", package = "GeomxTools"))

#Shift counts to one to mimic how DSPDA handles zero counts
testData <- shiftCountsOne(testData, elt="exprs", useDALogic=TRUE) 

##### Technical Signal QC #####

testData <- setSeqQCFlags(testData, 
                          qcCutoffs=list(minSegmentReads=1000, 
                                         percentAligned=80, 
                                         percentSaturation=50))
prData <- protocolData(testData)
TechSigQC <- as.data.frame(prData[["QCFlags"]])

# req 1: test that the number of Low Reads is correct:------
testthat::test_that("test that the number of Low Reads is correct", {
  expect_true(sum(TechSigQC$LowReads) == sum(prData@data$Raw < 1000))
})


# req 2: test that the number of Low Percent Trimmed is correct:------
testthat::test_that("test that the number of Low Percent Trimmed is correct", {
  expect_true(sum(TechSigQC$LowTrimmed) == sum(prData@data$`Trimmed (%)` < 80))
})


# req 3: test that the number of Low Percent Stiched is correct:------
testthat::test_that("test that the number of Low Percent Stiched is correct", {
  expect_true(sum(TechSigQC$LowStitched) == sum(prData@data$`Stitched (%)` < 80))
})


# req 4: test that the number of Low Percent Aligned is correct:------
testthat::test_that("test that the number of Low Percent Aligned is correct", {
  expect_true(sum(TechSigQC$LowAligned) == sum(prData@data$`Aligned (%)` < 80))
})


# req 5: test that the number of Low Percent Saturation is correct:------
testthat::test_that("test that the number of Low Percent Saturation is correct", {
  expect_true(sum(TechSigQC$LowSaturation) == sum(prData@data$`Saturated (%)` < 50))
})




##### Technical Background QC #####

neg_set <- exprs(negativeControlSubset(testData))

testData <- setBackgroundQCFlags(testData, 
                                 qcCutoffs=list(minNegativeCount=10, 
                                                maxNTCCount=60))

testData <- summarizeNegatives(testData)
prData <- protocolData(testData)
TechBgQC <- as.data.frame(prData[["QCFlags"]])

# req 1: test that the number of Low Negatives is correct:------
testthat::test_that("test that the number of Low Negatives is correct", {
    numberFail <- (pData(testData)[, "NegGeoMean_VnV_GeoMx_Hs_CTA_v1.2"] < 10) + 
                  (pData(testData)[, "NegGeoMean_Six-gene_test_v1_v1.1"] < 10)
    expect_true(sum(TechBgQC$LowNegatives) ==  sum(numberFail > 0)) 
})


# req 2: test that the number of High NTC is correct:------
testthat::test_that("test that the number of High NTC is correct", {
  expect_true(sum(TechBgQC$HighNTC) == sum(prData@data$NTC > 60))
})




##### Segment QC #####

testData <- setGeoMxQCFlags(testData, 
                            qcCutoffs=list(minNuclei=16000,
                                           minArea=20))
prData <- protocolData(testData)
segQC <- as.data.frame(prData[["QCFlags"]])

# req 1: test that the number of Low Area is correct:------
testthat::test_that("test that the number of Low Area is correct", {
  expect_true(sum(segQC$LowArea) == sum(sData(testData)[c("area")] < 20)) 
})


# req 2: test that the number of Low Nuclei is correct:------
testthat::test_that("test that the number of Low Nuclei is correct", {
  expect_true(sum(segQC$LowNuclei) == sum(testData@phenoData@data$nuclei < 16000))
})



##### Biological Probe QC #####

testData <- setBioProbeQCFlags(testData, 
                               qcCutoffs=list(minProbeRatio=0.1,
                                              percentFailGrubbs=20))


probeQC <- fData(testData)[["QCFlags"]]
subTest <- subset(testData, subset=Module == gsub(".pkc", "", annotation(testData)[[2]]))
neg_set <- negativeControlSubset(subTest)
probeQCResults <- data.frame(fData(neg_set)[["QCFlags"]], check.names = FALSE)

# req 1: test that the number of Low Probe Ratio is correct:------
testthat::test_that("test that the number of Low Probe Ratio is correct", {
  expect_true(sum(probeQC$LowProbeRatio) == sum(fData(testData)["ProbeRatio"] <= 0.1)) 
})



# req 2: test that the Local Grubbs Outlier is correct:
neg_set <- assayDataElement(neg_set, elt="preLocalRemoval")
neg_set <- neg_set[, !apply(neg_set, 2, function(x) {max(x) < 10L})]
neg_set <- logtBase(neg_set, base=10L)

test_results <- apply(neg_set, 2, outliers::grubbs.test, two.sided=TRUE)
test_list <- lapply(test_results, function(x) {x$p.value < 0.01})
test_outliers <- test_list[test_list == TRUE]
test_nonoutliers <- test_list[test_list == FALSE]
test_outliers <- lapply(test_outliers, function(x) {names(x)})
outlier_flags <- 
  lapply(names(test_outliers), 
         function(x) {probeQCResults[test_outliers[[x]], 
                                     paste0("LocalGrubbsOutlier.", x)]})
testthat::test_that("test that outliers detected are correct", {
  testthat::expect_true(all(unlist(outlier_flags))) 
})
outlier_count <- 
  apply(probeQCResults[, paste0("LocalGrubbsOutlier.", names(test_outliers))],
        2, 
        sum)
testthat::test_that("test that flagged sample/target sets have one outlier", {
  testthat::expect_true(all(outlier_count == 1)) 
})
nonoutlier_count <- 
  apply(probeQCResults[, paste0("LocalGrubbsOutlier.", names(test_nonoutliers))],
        2, 
        sum)
testthat::test_that("test that sample/target sets not flagged are correct", {
  testthat::expect_true(all(nonoutlier_count == 0)) 
})


# req 3: test that the Global Grubbs Outlier is correct:
globals_flagged <- rownames(probeQCResults)[which(probeQCResults$GlobalGrubbsOutlier==TRUE)]
probe_flag_percent <- 100 * table(t(as.data.frame(test_outliers))) / dim(testData)[["Samples"]]
global_outliers <- names(probe_flag_percent[probe_flag_percent >= 20])
testthat::test_that("flagged global outliers are correct", {
  testthat::expect_true(all(global_outliers %in% globals_flagged))
  testthat::expect_true(all(globals_flagged %in% global_outliers))
})
