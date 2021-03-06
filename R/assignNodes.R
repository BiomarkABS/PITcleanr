#' @title Assign Observation Nodes
#'
#' @description The function assigns PIT-tag observation node site names to each
#' tag detection history record generated from a PTAGIS 'complete tag history query'.  The
#' complete tag history query is completed by running the tag list outputted from the
#' validTagList() function. Observation node site names are assigned from joining a configuration
#' file with the PTAGIS query results on 'Site_Code' and 'AntennaID' fields. The configuration
#' file, 'siteDescription.csv', is distributed and maintained within the DABOM package.
#'
#' An observation node is a single or group of PIT-tag antenna that, at the finest resolution,
#' act as a unique tag detection location.  Often, a node consists of multiple antennas at a unique
#' PTAGIS interogation site, which together form a single array.  In addition, multiple nodes
#' may exist at one PTAGIS interogation site or mark-release-recapture (MRR) site when more than
#' antenna array are assigned to the same SiteID. A node may also be a single antenna or coil
#' located in an adult ladder or trap entry or the single (MRR) SiteID for fish handled and
#' scanned at a weir location.
#'
#' @author Kevin See
#'
#' @param valid_tag_df is a data frame containing the PIT tag ID in a column called \code{TagID}, and the date that fish was caught at the trap, \code{TrapDate}.
#'
#' @param observation is the PTAGIS observation file inputted as a data frame containing the complete tag history for each of the tagIDs in valid_tags
#'
#' @param configuration is a data frame which assigns node names to unique SiteID, AntennaID, and site configuration ID combinations. It can be built with the function \code{buildConfig}.
#'
#' @param parent_child_df is a data frame created by \code{createParentChildDf}.
#'
#' @param truncate logical, subsets observations to those with valid nodes, observations dates greater than trapping date at LGD and then to the minimum observation date of each set of observation events at a node, multiple observation events can occur at one node if the observations are split by detections at other nodes. Default is \code{TRUE}.
#'
#' @param obs_input does the input file come from PTAGIS or DART?
#'
#' @import dplyr lubridate
#' @export
#' @return NULL
#' @examples assignNodes()

assignNodes = function(valid_tag_df = NULL,
                       observation = NULL,
                       configuration = NULL,
                       parent_child_df = NULL,
                       truncate = T,
                       obs_input = c('ptagis','dart')) {

  stopifnot(!is.null(valid_tag_df) |
              !is.null(observation) |
              !is.null(parent_child_df))

  obs_input = match.arg(obs_input)

  if(is.null(configuration)) {
    print('Building configuration file')
    configuration = buildConfig()
  }

  if(obs_input == 'ptagis'){

    if(!'Event Release Date Time Value' %in% names(observation)) {
      observation$`Event Release Date Time Value` = NA
    }

    obs_df <- valid_tag_df %>%
      select(TagID, TrapDate) %>%
      left_join(observation %>%
                  left_join(configuration %>%
                              select(SiteID, SiteType, SiteTypeName) %>%
                              distinct(),
                            by = c('Event Site Code Value' = 'SiteID')) %>%
                  mutate(ObsDate = ifelse(!is.na(`Event Release Date Time Value`) &
                                            is.na(`Antenna ID`) &
                                            SiteType == 'MRR' &
                                            SiteTypeName %in% c('Acclimation Pond', 'Hatchery', 'Hatchery Returns', 'Trap or Weir', 'Dam'),
                                          `Event Release Date Time Value`,
                                          `Event Date Time Value`)) %>%
                  select(TagID = `Tag Code`,
                         ObsDate,
                         SiteID = `Event Site Code Value`,
                         AntennaID = `Antenna ID`,
                         ConfigID = `Antenna Group Configuration Value`) %>%
                  mutate(ObsDate = lubridate::mdy_hms(ObsDate)),
                by = c('TagID')) %>%
      mutate(ValidDate = ifelse(ObsDate >= TrapDate, T, F)) %>%
      filter(!is.na(SiteID))
  }

  if(obs_input == 'dart'){

    obs_df <- valid_tag_df %>%
      right_join(observation %>%
                   mutate(config = if_else(is.na(config),0,config),
                          config = as.character(config),
                          obs_site = if_else(is.na(obs_type), rel_site, obs_site),
                          obs_time = if_else(is.na(obs_type), as_datetime(rel_date), obs_time)) %>%
                   #count(obs_site) %>%
                   left_join(configuration %>%
                               select(obs_site = SiteID, SiteType, SiteTypeName) %>%
                               distinct(obs_site, .keep_all = TRUE),
                             by = 'obs_site') %>%
                   select(TagID = tag_id,
                          ObsDate = obs_time,
                          SiteID = obs_site,
                          AntennaID = coil_id,
                          ConfigID = config),
                 by = 'TagID') %>%
      mutate(ValidDate = ifelse(ObsDate >= TrapDate, T, F)) %>%
      filter(!is.na(SiteID)) %>%
      ungroup()
  }

  # which sites are not in the configuration file
  tmp_df <- obs_df %>%
    select(SiteID, AntennaID, ConfigID) %>%
    distinct() %>%
    anti_join(configuration %>%
                select(SiteID, AntennaID, ConfigID) %>%
                distinct(),
              by = c("SiteID", "AntennaID", "ConfigID")) # removes joining message.

  if( nrow(tmp_df) > 0 ){

    cat( "The following SiteID - AntennaID - ConfigID combinations are in the observation file
         but not listed in the site configuration file.\n")

    for( i in 1: nrow(tmp_df) ){

      print( paste0(tmp_df$SiteID[i], " - ", tmp_df$AntennaID[i], " - ", tmp_df$ConfigID[i]))
    }

    cat("Observation records with these combinations are flagged with an 'ERROR' in the Node field\n")
  }

  obs_dat <- obs_df %>%
    left_join(configuration %>%
                select(SiteID,
                       AntennaID,
                       ConfigID,
                       Node,
                       ValidNode,
                       AntennaGroup,
                       SiteName,
                       SiteDescription),
              by = c('SiteID', 'AntennaID', 'ConfigID')) %>%
    mutate(Node = ifelse(Node %in% union(unique(parent_child_df$ParentNode), unique(parent_child_df$ChildNode)), Node, NA),
           Node = ifelse(is.na(Node), 'ERROR', Node),
           ValidNode = ifelse(Node == 'ERROR', F, T)) %>%
    arrange(TagID, ObsDate)

  if(truncate){

    obs_dat = obs_dat %>%
      filter(ValidDate == TRUE,
             ValidNode == TRUE) %>%
      group_by(TagID) %>%
      mutate(prev_node = lag(Node),
             node_event = nodeDetectionEvent(Node)) %>%
      group_by(TagID, node_event) %>%
      mutate(lastObsDate = max(ObsDate)) %>%
      ungroup() %>%
      filter(Node != prev_node | is.na(prev_node)) %>%
      select(-prev_node, -node_event) %>%
      select(TagID, TrapDate, ObsDate, lastObsDate, everything())

  } # truncate if statement

  return(obs_dat)

}
