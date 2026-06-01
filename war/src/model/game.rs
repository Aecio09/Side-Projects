use crate::model::entities::{CellState, Country};

#[derive(Clone)]
pub struct GameState {
    pub rows: usize,
    pub cols: usize,
    pub round: i32,
    pub current_turn_index: usize,
    pub turn_order: Vec<usize>,
    pub selected: Option<usize>,
    pub upgrade_target: Option<usize>,
    pub player_index: usize,
    pub rng_state: u32,
    pub ai_running: bool,
    pub cells: Vec<CellState>,
    pub countries: Vec<Country>,
}

impl GameState {
    pub fn new() -> Self {
        let rows = 5;
        let cols = 5;
        let map = vec![
            0, 0, 0, 1, 1, //
            0, 0, 2, 1, 1, //
            0, 2, 2, 2, 1, //
            3, 3, 2, 4, 4, //
            3, 3, 4, 4, 4, //
        ];
        let mut rng_state = 0x1234_5678;
        let mut cells = Vec::with_capacity(rows * cols);
        for (index, owner) in map.iter().enumerate() {
            let troops = 6 + (Self::rand(&mut rng_state) % 8) as i32;
            cells.push(CellState {
                row: index / cols,
                col: index % cols,
                owner: *owner,
                troops,
                barracks: false,
                factory: false,
            });
        }

        let countries = vec![
            Country {
                name: "Brasil",
                color: slint::Color::from_rgb_u8(59, 207, 134),
                territories: 0,
                resources: 120,
                army: 0,
                initiative: 0,
                alive: true,
            },
            Country {
                name: "Argentina",
                color: slint::Color::from_rgb_u8(79, 141, 255),
                territories: 0,
                resources: 110,
                army: 0,
                initiative: 0,
                alive: true,
            },
            Country {
                name: "Chile",
                color: slint::Color::from_rgb_u8(255, 102, 102),
                territories: 0,
                resources: 130,
                army: 0,
                initiative: 0,
                alive: true,
            },
            Country {
                name: "Peru",
                color: slint::Color::from_rgb_u8(255, 198, 64),
                territories: 0,
                resources: 100,
                army: 0,
                initiative: 0,
                alive: true,
            },
            Country {
                name: "Uruguai",
                color: slint::Color::from_rgb_u8(173, 128, 255),
                territories: 0,
                resources: 105,
                army: 0,
                initiative: 0,
                alive: true,
            },
        ];

        let mut state = Self {
            rows,
            cols,
            round: 1,
            current_turn_index: 0,
            turn_order: vec![],
            selected: None,
            upgrade_target: None,
            player_index: 0,
            rng_state,
            ai_running: false,
            cells,
            countries,
        };

        state.recalculate_stats();
        state.start_round();
        state
    }

    fn rand(rng_state: &mut u32) -> u32 {
        *rng_state = rng_state.wrapping_mul(1664525).wrapping_add(1013904223);
        *rng_state
    }

    pub fn recalculate_stats(&mut self) {
        for c in self.countries.iter_mut() {
            c.territories = 0;
            c.army = 0;
        }
        for cell in &self.cells {
            let c = &mut self.countries[cell.owner];
            c.territories += 1;
            c.army += cell.troops;
        }
        for c in self.countries.iter_mut() {
            c.alive = c.territories > 0;
        }
    }

    pub fn update_resources(&mut self) {
        for cell in self.cells.iter_mut() {
            let resource_mult = if cell.factory { 3 } else { 1 };
            let troop_mult = if cell.barracks { 3 } else { 1 };
            self.countries[cell.owner].resources += 6 * resource_mult;
            cell.troops += 1 * troop_mult;
        }
        self.recalculate_stats();
    }

    pub fn calculate_initiative(&mut self) {
        for c in self.countries.iter_mut() {
            if !c.alive {
                c.initiative = 0;
                continue;
            }
            let luck = (Self::rand(&mut self.rng_state) % 200) as i32;
            let base = c.resources + c.army * 2 + luck;
            c.initiative = base.max(0) as u32;
        }
    }

    pub fn radix_sort_order(&self, indices: &mut [usize]) {
        let mut output = vec![0usize; indices.len()];
        let mut exp = 1u32;
        let mut max_val = 0u32;
        for &i in indices.iter() {
            max_val = max_val.max(self.countries[i].initiative);
        }
        while max_val / exp > 0 {
            let mut count = [0usize; 10];
            for &i in indices.iter() {
                let digit = ((self.countries[i].initiative / exp) % 10) as usize;
                count[digit] += 1;
            }
            for i in 1..10 {
                count[i] += count[i - 1];
            }
            for &i in indices.iter().rev() {
                let digit = ((self.countries[i].initiative / exp) % 10) as usize;
                count[digit] -= 1;
                output[count[digit]] = i;
            }
            indices.copy_from_slice(&output);
            exp *= 10;
        }
        indices.reverse();
    }

    pub fn start_round(&mut self) {
        self.update_resources();
        self.calculate_initiative();
        let mut order: Vec<usize> = self
            .countries
            .iter()
            .enumerate()
            .filter(|(_, c)| c.alive)
            .map(|(i, _)| i)
            .collect();
        self.radix_sort_order(&mut order);
        self.turn_order = order;
        self.current_turn_index = 0;
    }

    pub fn current_country_index(&self) -> Option<usize> {
        self.turn_order.get(self.current_turn_index).copied()
    }

    pub fn is_player_turn(&self) -> bool {
        self.current_country_index() == Some(self.player_index)
    }

    pub fn next_turn(&mut self) {
        self.selected = None;
        self.upgrade_target = None;
        if self.current_turn_index + 1 >= self.turn_order.len() {
            self.round += 1;
            self.start_round();
        } else {
            self.current_turn_index += 1;
        }
    }

    pub fn adjacent_indices(&self, index: usize) -> Vec<usize> {
        let r = index / self.cols;
        let c = index % self.cols;
        let mut out = Vec::new();
        if r > 0 {
            out.push((r - 1) * self.cols + c);
        }
        if r + 1 < self.rows {
            out.push((r + 1) * self.cols + c);
        }
        if c > 0 {
            out.push(r * self.cols + (c - 1));
        }
        if c + 1 < self.cols {
            out.push(r * self.cols + (c + 1));
        }
        out
    }

    pub fn try_attack(&mut self, attacker_index: usize, defender_index: usize) -> bool {
        let attacker_owner = self.cells[attacker_index].owner;
        let defender_owner = self.cells[defender_index].owner;
        if attacker_owner == defender_owner {
            return false;
        }
        if self.cells[attacker_index].troops < 2 {
            return false;
        }
        let attack_bonus = (Self::rand(&mut self.rng_state) % 4) as i32;
        let defend_bonus = (Self::rand(&mut self.rng_state) % 4) as i32;
        let attack_power = self.cells[attacker_index].troops + attack_bonus;
        let defend_power = self.cells[defender_index].troops + defend_bonus;

        if attack_power > defend_power {
            let moving = (self.cells[attacker_index].troops / 2).max(1);
            self.cells[attacker_index].troops -= moving;
            self.cells[defender_index].owner = attacker_owner;
            self.cells[defender_index].troops = moving;
            self.recalculate_stats();
            return true;
        }

        let loss = (defend_power / 2).max(1);
        self.cells[attacker_index].troops =
            (self.cells[attacker_index].troops - loss).max(1);
        self.recalculate_stats();
        false
    }

    pub fn move_troops(&mut self, from: usize, to: usize) -> bool {
        if self.cells[from].owner != self.cells[to].owner {
            return false;
        }
        if self.cells[from].troops < 2 {
            return false;
        }
        let moving = (self.cells[from].troops / 2).max(1);
        self.cells[from].troops -= moving;
        self.cells[to].troops += moving;
        self.recalculate_stats();
        true
    }

    pub fn build_barracks(&mut self, index: usize) -> bool {
        if self.cells[index].barracks {
            return false;
        }
        let owner = self.cells[index].owner;
        if self.countries[owner].resources < 300 {
            return false;
        }
        self.countries[owner].resources -= 300;
        self.cells[index].barracks = true;
        true
    }

    pub fn build_factory(&mut self, index: usize) -> bool {
        if self.cells[index].factory {
            return false;
        }
        let owner = self.cells[index].owner;
        if self.countries[owner].resources < 300 {
            return false;
        }
        self.countries[owner].resources -= 300;
        self.cells[index].factory = true;
        true
    }

    pub fn ai_action(&mut self, ai_index: usize) -> Option<(usize, usize)> {
        let mut best_attack: Option<(usize, usize, i32)> = None;
        for i in 0..self.cells.len() {
            if self.cells[i].owner != ai_index {
                continue;
            }
            for neigh in self.adjacent_indices(i) {
                if self.cells[neigh].owner == ai_index {
                    continue;
                }
                let diff = self.cells[i].troops - self.cells[neigh].troops;
                if diff > 0 {
                    if best_attack.map_or(true, |(_, _, d)| diff > d) {
                        best_attack = Some((i, neigh, diff));
                    }
                }
            }
        }
        if let Some((from, to, _)) = best_attack {
            self.try_attack(from, to);
            return Some((from, to));
        }
        None
    }

    pub fn check_winner(&self) -> Option<usize> {
        let alive: Vec<usize> = self
            .countries
            .iter()
            .enumerate()
            .filter(|(_, c)| c.alive)
            .map(|(i, _)| i)
            .collect();
        if alive.len() == 1 {
            return Some(alive[0]);
        }
        None
    }
}
