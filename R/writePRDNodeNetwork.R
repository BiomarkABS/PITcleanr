#' @title Priest Dam Node Network
#'
#' @description Create data.frame describing all the observation nodes in the Priest dam version of DABOM, including how they are related to one another
#'
#' @author Kevin See
#'
#'
#' @import dplyr tibble stringr
#' @export
#' @return NULL
#' @examples writePRDNodeNetwork()

writePRDNodeNetwork = function() {

  bin_names = c('Wenatchee',
                'Entiat',
                'Methow',
                'Okanogan',
                'BelowPriest')
  bin_list = vector('list', length(bin_names))
  names(bin_list) = bin_names

  bin_list[['Wenatchee']] = list('CLK',
                                 'LWE' =
                                   list('LWE',
                                        'MCL',
                                        'CHM',
                                        'PES' =
                                          list('PES',
                                               'PEU'),
                                        'ICL' =
                                          list('ICL',
                                               'LNF',
                                               'ICM' =
                                                 list('ICM',
                                                      'ICU')),
                                        'TUM' =
                                          list('TUM',
                                               'CHW',
                                               'CHL' =
                                                 list('CHL',
                                                      'CHU'),
                                               'UWE' =
                                                 list('UWE',
                                                      'WTL',
                                                      'LWN',
                                                      'NAL' =
                                                        list('NAL',
                                                             'NAU')))))

  bin_list[['Entiat']] = list('ENL' =
                                list('ENL',
                                     'RCT',
                                     'EHL',
                                     'MAD',
                                     'ENA' =
                                       list('ENA',
                                            'ENM' =
                                              list('ENM',
                                                   'ENS' =
                                                     list('ENS',
                                                          'ENF')))))

  bin_list[['Methow']] = list('LMR' =
                                list('LMR',
                                     'GLC',
                                     'LBC',
                                     'MRC' =
                                       list('MRC',
                                            'BVC',
                                            'TWR',
                                            'SCP',
                                            'MSH',
                                            'MRW' =
                                              list('MRW',
                                                   'WFC'),
                                            'CRW' =
                                              list('CRW',
                                                   'CRU'))))

  bin_list[['Okanogan']] = list('FST',
                                'OKL' =
                                  list('OKL',
                                       'LLC',
                                       'SA1' =
                                         list('SA1',
                                              'SA0'),
                                       'JOH',
                                       'AEN',
                                       'OMK' =
                                         list('OMK',
                                              'OBF'),
                                       'WAN',
                                       'TNK',
                                       'BPC',
                                       'ANT',
                                       'WHS',
                                       'ZSL' =
                                         list('ZSL',
                                              'TON',
                                              'NMC',
                                              'OKC')))

  bin_list[['BelowPriest']] = list('BelowJD1',
                                   'JD1',
                                   'TMF',
                                   'ICH',
                                   'PRH',
                                   'RSH',
                                   'PRO',
                                   'PRV' =
                                     list('PRV',
                                          'HST',
                                          'MDR'))

  bin_all = list('BelowPriest' = bin_list[['BelowPriest']],
                 'RIA' =
                   list('RIA',
                        'Wenatchee' = bin_list[['Wenatchee']],
                        'RRF' =
                          list('RRF',
                               'EBO',
                               'Entiat' = bin_list[['Entiat']],
                               'WVT',
                               'WEA' =
                                 list('WEA',
                                      'Methow' = bin_list[['Methow']],
                                      'Okanogan' = bin_list[['Okanogan']]))))



  site_df_init = dplyr::tibble(SiteID = unlist(bin_all),
                               path = names(unlist(bin_all))) %>%
    dplyr::mutate(path = stringr::str_replace(path,
                                              '[[:digit:]]$',
                                              ''),
                  path = stringr::str_replace(path,
                                              'WEA1$',
                                              'WEA'),
                  path = stringr::str_replace(path,
                                              'OKL1$',
                                              'OKL') ) %>% #,
    dplyr::mutate(path = ifelse(stringr::str_sub(path, start = -nchar(SiteID)) != SiteID,
                                paste(path, SiteID, sep = '.'),
                                path))

  network_descrip = stringr::str_split(site_df_init$path,
                                       '\\.',
                                       simplify = T)
  colnames(network_descrip) = paste0('Step', 1:ncol(network_descrip))

  site_df = site_df_init %>%
    dplyr::bind_cols(network_descrip %>%
                       as.data.frame()) %>%
    dplyr::mutate_at(vars(matches('^Step')),
                     funs(as.character)) %>%
    dplyr::mutate(SiteID = factor(SiteID,
                                  levels = unique(site_df_init$SiteID))) %>%
    dplyr::arrange(SiteID)


  return(site_df)


}