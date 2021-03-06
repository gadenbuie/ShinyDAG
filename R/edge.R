# rve$edges is a named list, e.g. for hash(A) -> hash(B):
# rve$edges[edge_key(hash(A), hash(B))] = list(from = hash(A), to = hash(B))

# ---- Edge Helper Functions ----
edge_key <- function(x, y) digest::digest(c(x, y))

edge_frame <- function(edges, nodes, ...) {
  dots <- rlang::enexprs(...)
  
  dag_edges <- edges_in_dag(edges, nodes)
  
  if (!length(dag_edges)) return(tibble())
  
  ensure_exists <- function(x, ...) {
    cols <- list(...)
    stopifnot(!is.null(names(cols)), all(nzchar(names(cols))))
    for (col in names(cols)) {
      x[[col]] <- x[[col]] %||% cols[[col]]
    }
    x %>% tidyr::replace_na(cols)
  }
  
  edges %>%
    bind_rows(.id = "hash") %>% 
    filter(hash %in% edges_in_dag(edges, nodes)) %>% 
    tidyr::nest(-from) %>% 
    left_join(
      nodes %>% node_frame() %>% select(from = hash, from_name = name),
      by = "from"
    ) %>% 
    tidyr::unnest() %>% 
    tidyr::nest(-to) %>% 
    left_join(
      nodes %>% node_frame() %>% select(to = hash, to_name = name),
      by = "to"
    ) %>% 
    tidyr::unnest() %>% 
    select(hash, names(edges[[1]]), everything()) %>% 
    ensure_exists(angle = 0L, color = "black", lty = "solid", lineT = "thin") %>% 
    mutate(!!!dots)
}

edges_in_dag <- function(edges, nodes) {
  if (!length(nodes) || !length(edges)) return(character())
  all_edges <- bind_rows(edges) %>%
    mutate(hash = names(edges)) %>%
    tidyr::gather(position, node_hash, from:to)
  
  edges_not_in_graph <- all_edges %>%
    filter(!node_hash %in% nodes_in_dag(nodes))
  
  setdiff(all_edges$hash, edges_not_in_graph$hash)
}

edge_edges <- function(edges, nodes, ...) {
  do.call(edge, as.list(edge_frame(edges, nodes, ...)))
}

edge_exists <- function(edges, from_hash = NULL, to_hash = NULL) {
  if (purrr::some(list(from_hash, to_hash), is.null)) return(FALSE)
  
  edges %>% 
    purrr::keep(~ .$from %in% from_hash) %>% 
    purrr::keep(~ .$to %in% to_hash) %>% 
    length() %>% 
    `>`(0)
}

edge_points <- function(edges, nodes, push_by = 0) {
  dag_edges <- edges_in_dag(edges, nodes)
  
  if (!length(dag_edges)) return(tibble())
  
  edge_frame(edges, nodes) %>% 
    tidyr::nest(-from) %>% 
    left_join(
      nodes %>% node_frame() %>% select(from = hash, from.x = x, from.y = y),
      by = "from"
    ) %>% 
    tidyr::unnest() %>% 
    tidyr::nest(-to) %>% 
    left_join(
      nodes %>% node_frame() %>% select(to = hash, to.x = x, to.y = y),
      by = "to"
    ) %>% 
    tidyr::unnest() %>% 
    select(hash, names(edges[[1]]), everything()) %>% 
    mutate(
      d_x = to.x - from.x,
      d_y = to.y - from.y,
      from.x = from.x + push_by * d_x,
      from.y = from.y + push_by * d_y,
      to.x = to.x - push_by * d_x,
      to.y = to.y - push_by * d_y,
      color = if_else(color == "", "Black", color)
    ) %>% 
    select(-d_x, -d_y)
}

edge_toggle <- function(edges, from_hash, to_hash) {
  existing <- 
    edges %>% 
    purrr::keep(~ .$from == from_hash) %>% 
    purrr::keep(~ .$to == to_hash)
  
  if (length(existing)) {
    for (edge_key in names(existing)) {
      edges[[edge_key]] <- NULL
    }
  } else {
    edges[[edge_key(from_hash, to_hash)]] <- list(from = from_hash, to = to_hash)
  }
  edges
}
