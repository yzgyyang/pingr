
#' Check if a remote computer is up
#'
#' @useDynLib ping
#' @docType package
#' @name ping-package
NULL

#' Check if a port of a server is active, measure response time
#'
#' @param destination Host name or IP address.
#' @param port Port.
#' @param type Protocol, \sQuote{tcp} or \sQuote{udp}.
#' @param continuous Logical, whether to keep pinging until
#'   the user interrupts.
#' @param count Number of pings to perform.
#' @param timeout Timeout, in seconds. How long to wait for a
#'   ping to succeed.
#' @return Vector of response times. \code{NA} means no response
#'
#' @export

ping_port <- function(destination, port = 80L, type = c("tcp", "udp"),
                      continuous = FALSE, count = 3L, timeout = 1.0) {

  type <- switch(match.arg(type), "tcp" = 0L, "udp" = 1L)
  timeout <- as.integer(timeout * 1000000)
  res <- .Call("r_ping", destination, port, type, continuous, count, timeout,
               PACKAGE = "ping")
  res[ res == -1 ] <- NA_real_
  res
}

#' Ping a remote server, to see if it is alive
#'
#' This is the classic ping, using ICMP packages. Only the
#' system administrator can send ICMP packages, so we call out
#' to the system's ping utility.
#'
#' @param destination Host name or IP address.
#' @param continuous Logical, whether to keep pinging until the
#'   user interrupts.
#' @param count Number of pings to perform.
#' @param timeout Timeout for a ping response.
#' @return Vector of response times. \code{NA} means no response, in
#'   seconds. Currently \code{NA}s are always at the end of the vector,
#'   and not in their correct position.
#'
#' @export

ping <- function(destination, continuous = FALSE, count = 3L,
                 timeout = 1.0) {

  os <- ping_os(destination, continuous, count, timeout)

  output <- suppressWarnings(system(os$cmd, intern = ! continuous))

  if (!continuous) {
    timings <- grep(os$regex, output, value = TRUE, perl = TRUE)
    times <- sub(os$regex, "\\1", timings, perl = TRUE)
    res <- as.numeric(times)
    length(res) <- count
    res
  } else {
    invisible()
  }
}

ping_os <- function(destination, continuous, count, timeout) {

  if (.Platform$OS.type == "windows") {
    ping_file <- file.path("C:", "windows", "system32", "ping.exe")
    if (!file.exists(ping_file)) { ping_file <- "ping" }
    cmd <- ping_file %+% " -W " %+% chr(int(timeout * 1000))
    if (continuous) {
      cmd <- cmd %+% " -t"
    } else {
      cmd <- cmd %+% " -n " %+% chr(count)
    }
    cmd <- cmd %+% " " %+% destination

  } else if (Sys.info()["sysname"] == "Darwin") {
    cmd <- "/sbin/ping " %+% "-W " %+% chr(int(timeout * 1000))
    if (!continuous) cmd <- cmd %+% " -c " %+% chr(count)
    cmd <- cmd %+% " " %+% destination

  } else if (.Platform$OS.type == "unix") {
    cmd <- "ping " %+% "-W " %+% chr(int(timeout * 1000))
    if (!continuous) cmd <- cmd %+% " -c " %+% chr(count)
    cmd <- cmd %+% " " %+% destination

  } else {
    ## We are probably on some Unix, so search for ping
    if (file.exists("/sbin/ping")) {
      ping_file <- "/sbin/ping"
    } else if (file.exists("/usr/sbin/ping")) {
      ping_file <- "/usr/sbin/ping"
    } else if (file.exists("/bin/ping")) {
      ping_file <- "/bin/ping"
    } else if (file.exists("/usr/bin/ping")) {
      ping_file <- "/usr/bin/ping"
    } else {
      ping_file <- "ping"
    }
    cmd <- ping_file %+% " -W " %+% chr(int(timeout * 1000))
    if (!continuous) cmd <- cmd %+% " -c " %+% chr(count)
    cmd <- cmd %+% " " %+% destination

  }

  list(cmd = cmd, regex = "^.*time=(.+)[ ]?ms.*$")
}
