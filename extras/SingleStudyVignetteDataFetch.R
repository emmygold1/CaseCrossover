# Copyright 2017 Observational Health Data Sciences and Informatics
#
# This file is part of CaseCrossover
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This code should be used to fetch the data that is used in the vignettes.
library(CaseCrossover)
options(fftempdir = "s:/fftemp")

pw <- NULL
dbms <- "pdw"
user <- NULL
server <- "JRDUSAPSCTL01"
cdmDatabaseSchema <- "cdm_truven_mdcd_v521.dbo"
cohortDatabaseSchema <- "scratch.dbo"
oracleTempSchema <- NULL
cohortTable <- "mschuemi_cc_vignette"
port <- 17001

connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = dbms,
                                                                server = server,
                                                                user = user,
                                                                password = pw,
                                                                port = port)

connection <- DatabaseConnector::connect(connectionDetails)

sql <- SqlRender::loadRenderTranslateSql("vignette.sql",
                                         packageName = "CaseControl",
                                         dbms = dbms,
                                         cdmDatabaseSchema = cdmDatabaseSchema,
                                         cohortDatabaseSchema = cohortDatabaseSchema,
                                         cohortTable = cohortTable)

DatabaseConnector::executeSql(connection, sql)

# Check number of subjects per cohort:
sql <- "SELECT cohort_definition_id, COUNT(*) AS count FROM @cohortDatabaseSchema.@cohortTable GROUP BY cohort_definition_id"
sql <- SqlRender::renderSql(sql,
                            cohortDatabaseSchema = cohortDatabaseSchema,
                            cohortTable = cohortTable)$sql
sql <- SqlRender::translateSql(sql, targetDialect = connectionDetails$dbms)$sql
DatabaseConnector::querySql(connection, sql)

RJDBC::dbDisconnect(connection)


caseCrossoverData <- getDbCaseCrossoverData(connectionDetails = connectionDetails,
                                            cdmDatabaseSchema = cdmDatabaseSchema,
                                            oracleTempSchema = oracleTempSchema,
                                            outcomeDatabaseSchema = cohortDatabaseSchema,
                                            outcomeTable = cohortTable,
                                            outcomeId = 1,
                                            exposureDatabaseSchema = cdmDatabaseSchema,
                                            exposureTable = "drug_era",
                                            exposureIds = 1124300,
                                            useNestingCohort = TRUE,
                                            nestingCohortDatabaseSchema = cohortDatabaseSchema,
                                            nestingCohortTable = cohortTable,
                                            nestingCohortId = 2,
                                            useObservationEndAsNestingEndDate = TRUE,
                                            getTimeControlData = TRUE)

saveCaseCrossoverData(caseCrossoverData, "s:/temp/vignetteCaseCrossover/caseCrossoverData")

caseCrossoverData <- loadCaseCrossoverData("s:/temp/vignetteCaseCrossover/caseCrossoverData")

caseCrossoverData

summary(caseCrossoverData)

# Case-crossover ----------------------------------------------------------

subjects <- selectSubjectsToInclude(caseCrossoverData = caseCrossoverData,
                                    outcomeId = 1,
                                    firstOutcomeOnly = TRUE,
                                    washoutPeriod = 183)

head(subjects)
saveRDS(subjects, "s:/temp/vignetteCaseCrossover/subjects.rds")

exposureStatus <- getExposureStatus(subjects = subjects,
                                    caseCrossoverData = caseCrossoverData,
                                    exposureId = 1124300,
                                    firstExposureOnly = FALSE,
                                    riskWindowStart = -30,
                                    riskWindowEnd = 0,
                                    controlWindowOffsets = c(-60))
head(exposureStatus)

saveRDS(exposureStatus, "s:/temp/vignetteCaseCrossover/exposureStatus.rds")


fit <- fitCaseCrossoverModel(exposureStatus)
saveRDS(fit, "s:/temp/vignetteCaseCrossover/fit.rds")

# Case-time-control -------------------------------------------------------

matchingCriteria <- createMatchingCriteria(controlsPerCase = 1,
                                           matchOnAge = TRUE,
                                           ageCaliper = 2,
                                           matchOnGender = TRUE)

subjectsCtc <- selectSubjectsToInclude(caseCrossoverData = caseCrossoverData,
                                       outcomeId = 1,
                                       firstOutcomeOnly = TRUE,
                                       washoutPeriod = 183,
                                       matchingCriteria = matchingCriteria)

exposureStatusCtc <- getExposureStatus(subjects = subjectsCtc,
                                       caseCrossoverData = caseCrossoverData,
                                       exposureId = 1124300,
                                       firstExposureOnly = FALSE,
                                       riskWindowStart = -30,
                                       riskWindowEnd = 0,
                                       controlWindowOffsets = c(-60))

fitCtc <- fitCaseCrossoverModel(exposureStatusCtc)

summary(fitCtc)
saveRDS(fitCtc, "s:/temp/vignetteCaseCrossover/fitCtc.rds")


