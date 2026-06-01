#[derive(Clone)]
pub struct CellState {
    pub row: usize,
    pub col: usize,
    pub owner: usize,
    pub troops: i32,
    pub barracks: bool,
    pub factory: bool,
}
