use amaru_kernel::Point;
use anyhow::Result;
use pallas_network::miniprotocols::blockfetch::Body;

/// Struct to hold the critical header and block information for comparison.
#[derive(Debug, Clone)]
pub struct HeaderInfo {
    pub slot: u64,
    pub hash: Vec<u8>,
    // The Point required to fetch the full block later
    pub point: Point,
}

/// Groups peer divergence information for reporting.
pub struct PeerDivergence<'a> {
    pub host: &'a str,
    pub header: &'a HeaderInfo,
    pub block_result: &'a Result<Body>,
}
