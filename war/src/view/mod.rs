use crate::model::GameState;
use slint::{Model, SharedString, VecModel};
use std::rc::Rc;

slint::include_modules!();


pub fn build_cell_data(state: &GameState, index: usize) -> CellData {
    let cell = &state.cells[index];
    let country = &state.countries[cell.owner];
    let mut upgrades = String::new();
    if cell.barracks {
        upgrades.push('Q');
    }
    if cell.factory {
        upgrades.push('F');
    }
    let label = if upgrades.is_empty() {
        format!("{}\n{}", country.name.chars().next().unwrap(), cell.troops)
    } else {
        format!(
            "{}\n{} {}",
            country.name.chars().next().unwrap(),
            cell.troops,
            upgrades
        )
    };
    CellData {
        row: cell.row as i32,
        col: cell.col as i32,
        label: SharedString::from(label),
        color: country.color,
        selected: state.selected == Some(index) || state.upgrade_target == Some(index),
    }
}

pub fn play_attack_animation(app: &AppWindow, state: &GameState, from: usize, to: usize) {
    let from_cell = &state.cells[from];
    let to_cell = &state.cells[to];
    app.set_attack_active(true);
    app.set_attack_from_row(from_cell.row as i32);
    app.set_attack_from_col(from_cell.col as i32);
    app.set_attack_to_row(to_cell.row as i32);
    app.set_attack_to_col(to_cell.col as i32);
    app.set_attack_progress(0.0);
    let weak = app.as_weak();
    slint::Timer::single_shot(std::time::Duration::from_millis(10), move || {
        if let Some(app) = weak.upgrade() {
            app.set_attack_progress(1.0);
        }
    });
    let weak = app.as_weak();
    slint::Timer::single_shot(std::time::Duration::from_millis(1000), move || {
        if let Some(app) = weak.upgrade() {
            app.set_attack_active(false);
            app.set_attack_progress(0.0);
        }
    });
}

pub fn refresh_cells(state: &GameState, cell_model: &Rc<VecModel<CellData>>) {
    for i in 0..state.cells.len() {
        cell_model.set_row_data(i, build_cell_data(state, i));
    }
}

pub fn update_order_model(state: &GameState, order_model: &Rc<VecModel<SharedString>>) {
    order_model.set_vec(
        state
            .turn_order
            .iter()
            .map(|&i| {
                let c = &state.countries[i];
                SharedString::from(format!("{}: {}", c.name, c.initiative))
            })
            .collect::<Vec<SharedString>>(),
    );
}

pub fn update_texts(app: &AppWindow, state: &GameState) {
    let current = state
        .current_country_index()
        .map(|i| state.countries[i].name)
        .unwrap_or("Nenhum");
    app.set_round_text(SharedString::from(format!("Rodada {}", state.round)));
    app.set_current_text(SharedString::from(format!("Vez de: {}", current)));

    if let Some(winner) = state.check_winner() {
        let msg = format!(
            "Vitória de {}! Todos os territórios foram conquistados.",
            state.countries[winner].name
        );
        app.set_status_text(SharedString::from(msg));
        return;
    }

    let player = &state.countries[state.player_index];
    let status = format!(
        "Seu país: {} | Territórios: {} | Recursos: {} | Exército: {}",
        player.name, player.territories, player.resources, player.army
    );
    app.set_status_text(SharedString::from(status));
}
