trait MinMax<T> {
    fn min(lhs: T, rhs: T) -> T;
    fn max(lhs: T, rhs: T) -> T;
}

impl U256MinMax of MinMax<u256> {
    fn min(lhs: u256, rhs: u256) -> u256 {
        if lhs < rhs {
            lhs
        } else {
            rhs
        }
    }

    fn max(lhs: u256, rhs: u256) -> u256 {
        if lhs > rhs {
            lhs
        } else {
            rhs
        }
    }
}