#' @title Capture History Output
#'
#' @description This function combines the results from \code{writeFishPaths} and \code{writeSpwnPaths} functions and saves it as an excel file if desired.
#'
#' @param valid_obs dataframe built by the function \code{assignNodes}.
#'
#' @param valid_paths dataframe built by the function \code{getValidPaths}
#'
#' @param save_file Should output be written to an Excel file? Default value is \code{FALSE}.
#'
#' @param file_name If \code{save_file == TRUE}, this is the file name (with possible extension) to be saved to.
#'
#' @author Kevin See
#' @import dplyr WriteXLS
#' @export

writeCapHistOutput = function(valid_obs = NULL,
                              valid_paths = NULL,
                              save_file = F,
                              file_name = NULL) {

  stopifnot(!is.null(valid_obs), !is.null(valid_paths))

  if(is.null(file_name) & save_file) file_name = 'CapHistOutput.xlsx'

  fish_paths = writeFishPaths(valid_obs,
                              valid_paths)
  spwn_paths = writeSpwnPaths(valid_obs,
                              valid_paths)


  save_df = fish_paths %>%
    rename(ObsDate = MinObsDate) %>%
    full_join(spwn_paths %>%
                select(TagID, TrapDate, ObsDate:SiteID, Node, SiteName, SiteDescription, NodeOrder:ModelObs)) %>%
    arrange(TrapDate, TagID, ObsDate) %>%
    select(TagID, TrapDate, ObsDate, SiteID, Node,
           AutoProcStatus, UserProcStatus,
           NodeOrder:ModelObs,
           SiteDescription, UserComment)

  if(!save_file) return(save_df)

  if(save_file) {
    WriteXLS('save_df',
             file_name,
             SheetNames = c('ProcCapHist'),
             AdjWidth = T,
             AutoFilter = T,
             BoldHeaderRow = T,
             FreezeCol = 1,
             FreezeRow = 1)
  }
}