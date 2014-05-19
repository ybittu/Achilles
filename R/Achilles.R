# @file Achilles
#
# Copyright 2014 Observational Health Data Sciences and Informatics
#
# This file is part of Achilles
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
#
# @author Observational Health Data Sciences and Informatics
# @author Martijn Schuemie
# @author Patrick Ryan

executeSql <- function(conn, dbms, sql){
  sqlStatements = splitSql(sql)
  progressBar <- txtProgressBar()
  for (i in 1:length(sqlStatements)){
    sqlStatement <- sqlStatements[i]
    tryCatch ({	  
      dbSendUpdate(conn, sqlStatement)
    } , error = function(err) {
      writeLines(paste("Error executing SQL:",err))
      
      #Write error report:
      filename <- paste(getwd(),"/errorReport.txt",sep="")
      sink(filename)
      error <<- err
      cat("DBMS:\n")
      cat(dbms)
      cat("\n\n")
      cat("Error:\n")
      cat(err$message)
      cat("\n\n")
      cat("SQL:\n")
      cat(sqlStatement)
      sink()
      
      writeLines(paste("An error report has been created at ", filename))
      break
    })
    setTxtProgressBar(progressBar, i/length(sqlStatements))
  }
  close(progressBar)
}

renderAndTranslate <- function(sqlFilename, packageName, dbms, ...){
  pathToSql <- system.file(paste("sql/",gsub(" ","_",dbms),sep=""), sqlFilename, package=packageName)
  mustTranslate <- !file.exists(pathToSql)
  if (mustTranslate) # If DBMS-specific code does not exists, load SQL Server code and translate after rendering
    pathToSql <- system.file(paste("sql/","sql_server",sep=""), sqlFilename, package=packageName)      
  parameterizedSql <- readChar(pathToSql,file.info(pathToSql)$size)  
  
  renderedSql <- renderSql(parameterizedSql[1], ...)$sql
  
  if (mustTranslate)
    renderedSql <- translateSql(renderedSql, "sql server", dbms)$sql
  
  renderedSql
}


#' @title achilles
#'
#' @description
#' \code{achilles} creates descriptive statistics summary for an entire OMOP CDM instance.
#'
#' @details
#' PATRICK HOMEWORK:   complete details
#' 
#' 
#' @param connectionDetails	An R object of type ConnectionDetail (details for the function that contains server info, database type, optionally username/password, port)
#' @param cdmSchema			string name of databsae schema that contains OMOP CDM and vocabulary
#' @param resultsSchema		string name of database schema that we can write results to
#' @param sourceName		string name of the database, as recorded in results
#' @param analysisIds		(optional) a vector containing the set of Achilles analysisIds for which results will be generated.
#' If not specified, all analyses will be executed.
#' 
#' @return An object of type \code{oscarResults} containing details for connecting to the database containing the results 
#' @examples \dontrun{
#'   connectionDetails <- createConnectionDetails(dbms="sql server", server="RNDUSRDHIT07.jnj.com")
#'   achillesResults <- achilles(connectionDetails, "cdm4_sim", "scratch", "TestDB")
#'   plot(achillesResults, "population")
#' }
#' @export
achilles <- function (connectionDetails, cdmSchema, resultsSchema, sourceName = "", analysisIds){
	if (missing(analysisIds))
		analysisIds = all_analysis_ids
	
	renderedSql <- renderAndTranslate(sqlFilename = "Achilles.sql",
	                                  packageName = "Achilles",
                                    dbms = connectionDetails$dbms,
	                                  CDM_schema = cdmSchema, 
                                    results_schema = resultsSchema, 
                                    source_name = sourceName, 
                                    list_of_analysis_ids = analysisIds
                                    )
  
	conn <- connect(connectionDetails)
	
	writeLines("Executing multiple queries. This could take a while")
	executeSql(conn,connectionDetails$dbms,renderedSql)
	writeLines(paste("Done. Results can now be found in",resultsSchema))
	
	dbDisconnect(conn)
	
	resultsConnectionDetails <- connectionDetails
	resultsConnectionDetails$schema = resultsSchema
	result <- list(resultsConnectionDetails = resultsConnectionDetails, 
                 resultsTable = "ACHILLES_results",
                 resultsDistributionTable,"ACHILLES_results_dist",
                 analysis_table = "ACHILLES_analysis",
                 sourceName = sourceName,
                 analysisIds = analysisIds,
                 sql = renderedSql,
                 call = match.call())
	class(result) <- "achillesResults"
	result
}