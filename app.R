library(shiny)
library(bslib)
library(shinychat)
library(ellmer)
library(httr)
library(jsonlite)

# Interface utilisateur
ui <- page_fluid(
  tags$head(
    tags$link(rel = "stylesheet", 
              href="https://unpkg.com/@chrisoakman/chessboardjs@1.0.0/dist/chessboard-1.0.0.min.css"),
    tags$script(src = "https://code.jquery.com/jquery-3.5.1.min.js"),
    tags$script(src = "https://unpkg.com/@chrisoakman/chessboardjs@1.0.0/dist/chessboard-1.0.0.min.js"),
    tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/chess.js/0.10.3/chess.min.js"),
    tags$style(HTML("
      .stats-table {
        width: 100%;
        margin-top: 10px;
        font-size: 11px;
      }
      .stats-table th {
        background-color: #3f51b5;
        color: white;
        padding: 6px;
        text-align: left;
        font-size: 11px;
      }
      .stats-table td {
        padding: 4px 6px;
        border-bottom: 1px solid #ddd;
      }
      .stats-table tr:hover {
        background-color: #f5f5f5;
      }
      .rank-1 { font-weight: bold; color: #4caf50; }
      .rank-2 { color: #8bc34a; }
      .rank-3 { color: #ffc107; }
      .positive-eval { color: #4caf50; font-weight: bold; }
      .negative-eval { color: #f44336; font-weight: bold; }
      .neutral-eval { color: #666; }
      
      .result-bar {
        display: flex;
        width: 100%;
        height: 18px;
        border-radius: 3px;
        overflow: hidden;
        border: 1px solid #ddd;
      }
      .result-win {
        background-color: #4caf50;
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 9px;
        font-weight: bold;
      }
      .result-draw {
        background-color: #9e9e9e;
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 9px;
        font-weight: bold;
      }
      .result-loss {
        background-color: #f44336;
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 9px;
        font-weight: bold;
      }
      
      .trap-high { 
        color: #d32f2f; 
        font-weight: bold;
        background-color: #ffebee;
        padding: 2px 6px;
        border-radius: 3px;
      }
      .trap-medium { 
        color: #f57c00; 
        font-weight: bold;
      }
      .trap-low { 
        color: #999; 
      }
      
      .best-trap-row {
        background-color: #fff3e0 !important;
        border-left: 3px solid #ff9800;
      }
    ")),
    tags$script(HTML("
      var board = null;
      var game = new Chess();
      var moveHistory = [];
      
      function onDrop(source, target) {
        var move = game.move({
          from: source,
          to: target,
          promotion: 'q'
        });
        
        if (move === null) return 'snapback';
        
        moveHistory.push(game.fen());
        
        Shiny.setInputValue('last_move_san', move.san);
        Shiny.setInputValue('last_move_uci', source + target);
        Shiny.setInputValue('fen', game.fen());
        Shiny.setInputValue('move_trigger', new Date().getTime());
        Shiny.setInputValue('can_undo', moveHistory.length > 0);
        updateStatus();
      }
      
      function updateStatus() {
        var status = '';
        if (game.in_checkmate()) status = 'Échec et mat';
        else if (game.in_check()) status = 'Échec';
        Shiny.setInputValue('game_status', status);
      }
      
      function resetBoard() {
        game.reset();
        board.start();
        moveHistory = [];
        Shiny.setInputValue('fen', game.fen());
        Shiny.setInputValue('can_undo', false);
      }
      
      function loadFen(fen) {
        try {
          game.load(fen);
          board.position(fen);
          moveHistory = [fen];
          Shiny.setInputValue('fen', fen);
          Shiny.setInputValue('can_undo', false);
          console.log('Board mis à jour avec FEN:', fen);
        } catch(e) {
          console.error('Erreur lors du chargement du FEN:', e);
        }
      }
      
      function undoMove() {
        if (moveHistory.length > 1) {
          moveHistory.pop();
          var previousFen = moveHistory[moveHistory.length - 1];
          game.load(previousFen);
          board.position(previousFen);
          Shiny.setInputValue('fen', previousFen);
          Shiny.setInputValue('undo_trigger', new Date().getTime());
          Shiny.setInputValue('can_undo', moveHistory.length > 0);
        } else if (moveHistory.length === 1) {
          game.reset();
          board.start();
          moveHistory = [];
          Shiny.setInputValue('fen', game.fen());
          Shiny.setInputValue('undo_trigger', new Date().getTime());
          Shiny.setInputValue('can_undo', false);
        }
      }
      
      $(document).ready(function() {
        var config = {
          draggable: true,
          position: 'start',
          onDrop: onDrop,
          pieceTheme: 'https://chessboardjs.com/img/chesspieces/wikipedia/{piece}.png'
        };
        board = Chessboard('myBoard', config);
        moveHistory.push(game.fen());
      });
      
      Shiny.addCustomMessageHandler('reset_board', function(message) {
        resetBoard();
      });
      
      Shiny.addCustomMessageHandler('undo_move', function(message) {
        undoMove();
      });
      
      Shiny.addCustomMessageHandler('load_fen', function(fen) {
        loadFen(fen);
      });
      
      Shiny.addCustomMessageHandler('eval', function(message) {
        try {
          eval(message.code);
        } catch(e) {
          console.error('Erreur eval:', e);
        }
      });
    "))
  ),
  
  h2("🎓 Coach d'Échecs IA - Mode Blitz"),
  
  layout_columns(
    col_widths = c(6, 6),
    
    # Colonne gauche - Chat uniquement
    card(
      card_header("💬 Chat avec le Coach"),
      card_body(
        min_height = "650px",
        chat_ui("chess_coach")
      )
    ),
    
    # Colonne droite
    div(
      card(
        card_header("♟️ Échiquier"),
        card_body(
          div(
            style = "text-align: center; margin-bottom: 15px;",
            actionButton("btn_undo", "⬅️ Coup précédent", 
                         class = "btn-secondary",
                         style = "width: 48%; margin-right: 2%;"),
            actionButton("btn_reset", "🔄 Nouvelle partie", 
                         class = "btn-warning",
                         style = "width: 48%;")
          ),
          div(id = "myBoard", style = "width: 100%; max-width: 400px; margin: 0 auto;")
        )
      ),
      
      br(),
      
      card(
        card_header("📚 Stats Blitz >2200 + 🎯 Piège"),
        card_body(
          p(style = "font-size: 10px; color: #666; margin-bottom: 8px;",
            "🎯 Piège = % d'adversaires qui NE jouent PAS les 3 meilleurs coups"),
          htmlOutput("lichess_stats_display")
        )
      )
    )
  )
)

# Serveur
server <- function(input, output, session) {
  
  state <- reactiveValues(
    fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    previous_fen = NULL,
    last_move_san = NULL,
    stockfish_eval = NULL,
    previous_eval = NULL,
    lichess_stats = NULL,
    calculated_fen = NULL,
    trap_scores = list()
  )
  
  # Tool pour afficher une position après des coups
  show_position_tool <- tool(
    function(moves_sequence, description = "", from_current_position = TRUE) {
      starting_fen <- if (from_current_position && !is.null(state$fen)) {
        state$fen
      } else {
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
      }
      
      js_code <- sprintf("
        (function() {
          try {
            var chess = new Chess('%s');
            var moves = '%s'.split(' ');
            var success = true;
            
            for (var i = 0; i < moves.length; i++) {
              var move = moves[i].trim();
              if (move) {
                var result = chess.move(move, {sloppy: true});
                if (result === null) {
                  console.error('Coup invalide:', move);
                  success = false;
                  break;
                }
              }
            }
            
            if (success) {
              var finalFen = chess.fen();
              Shiny.setInputValue('calculated_fen', finalFen, {priority: 'event'});
              loadFen(finalFen);
            }
          } catch(e) {
            console.error('Erreur:', e);
          }
        })();
      ", starting_fen, moves_sequence)
      
      session$sendCustomMessage("eval", list(code = js_code))
      
      return(list(
        success = TRUE,
        message = paste("Position affichée:", description, "-", moves_sequence)
      ))
    },
    name = "show_position_after_moves",
    description = "Affiche une position après une séquence de coups. Part de la position actuelle par défaut.",
    arguments = list(
      moves_sequence = type_string("Coups en notation algébrique séparés par des espaces"),
      description = type_string("Description de la position", required = FALSE),
      from_current_position = type_boolean("Partir de la position actuelle (défaut: TRUE)", required = FALSE)
    )
  )
  
  # Tool pour mettre à jour avec un FEN
  update_board_tool <- tool(
    function(fen_position) {
      session$sendCustomMessage("load_fen", fen_position)
      state$fen <- fen_position
      state$stockfish_eval <- get_stockfish_analysis(fen_position)
      state$lichess_stats <- get_lichess_stats(fen_position)
      list(success = TRUE, message = paste("Position mise à jour:", fen_position))
    },
    name = "update_board",
    description = "Met à jour l'échiquier avec un FEN exact.",
    arguments = list(
      fen_position = type_string("Position FEN complète")
    )
  )
  
  # Chat IA
  chat <- chat_anthropic(
    model = "claude-sonnet-4-5-20250929",
    system_prompt = "Tu es un COACH d'échecs expert (2400+) spécialisé en BLITZ.

NOUVEAU: Tu as accès au score 'Piège' (🎯) = % d'adversaires qui ne jouent pas les 3 meilleurs coups.
- Score ÉLEVÉ (>40%) = coup très piégeux, l'adversaire va probablement se tromper!
- En blitz, privilégie les coups avec un bon score Piège + évaluation correcte.

TON RÔLE: Expliquer les coups, donner des plans concrets, suggérer des coups FORCING.
STYLE: Agressif, pratique, 5-8 lignes denses.

OUTILS: show_position_after_moves (affiche après des coups), update_board (FEN exact)",
    api_key = Sys.getenv("ANTHROPIC_API_KEY")
  )
  
  chat$register_tool(show_position_tool)
  chat$register_tool(update_board_tool)
  
  # Gestion du chat
  observeEvent(input$chess_coach_user_input, {
    req(input$chess_coach_user_input)
    
    context_parts <- c()
    
    if (!is.null(state$fen)) {
      context_parts <- c(context_parts, paste0("FEN: ", state$fen))
    }
    
    if (!is.null(state$last_move_san)) {
      context_parts <- c(context_parts, paste0("Dernier coup: ", state$last_move_san))
    }
    
    if (!is.null(state$stockfish_eval) && !is.null(state$stockfish_eval$pvs)) {
      top5 <- head(state$stockfish_eval$pvs, 5)
      sf_text <- "Top 5 Stockfish:\n"
      for (i in seq_along(top5)) {
        pv <- top5[[i]]
        eval_str <- if (!is.null(pv$cp)) sprintf("%.2f", pv$cp/100) else "Mat"
        moves_line <- paste(head(strsplit(pv$moves, " ")[[1]], 3), collapse = " ")
        sf_text <- paste0(sf_text, i, ". ", moves_line, " (", eval_str, ")\n")
      }
      context_parts <- c(context_parts, sf_text)
    }
    
    if (!is.null(state$lichess_stats) && length(state$lichess_stats$moves) > 0) {
      stats_text <- "Coups populaires + Piège:\n"
      for (i in 1:min(4, length(state$lichess_stats$moves))) {
        m <- state$lichess_stats$moves[[i]]
        total <- m$white + m$draws + m$black
        win_rate <- if (grepl(" w ", state$fen)) round((m$white / total) * 100, 0) else round((m$black / total) * 100, 0)
        trap_info <- if (!is.null(state$trap_scores[[m$uci]])) paste0(" 🎯", state$trap_scores[[m$uci]], "%") else ""
        stats_text <- paste0(stats_text, m$san, " (", win_rate, "% vic", trap_info, ")\n")
      }
      context_parts <- c(context_parts, stats_text)
    }
    
    full_message <- paste0(paste(context_parts, collapse = "\n\n"), "\n\nQuestion: ", input$chess_coach_user_input)
    
    stream <- chat$stream_async(full_message, stream = "content")
    chat_append("chess_coach", stream)
  })
  
  observeEvent(input$calculated_fen, {
    req(input$calculated_fen)
    state$fen <- input$calculated_fen
    state$stockfish_eval <- get_stockfish_analysis(input$calculated_fen)
    state$lichess_stats <- get_lichess_stats(input$calculated_fen)
    state$trap_scores <- list()
    calculate_trap_scores()
  })
  
  # === FONCTIONS API ===
  
  get_stockfish_analysis <- function(fen) {
    tryCatch({
      response <- GET("https://lichess.org/api/cloud-eval", query = list(fen = fen, multiPv = 20))
      if (status_code(response) == 200) return(content(response, "parsed"))
      return(NULL)
    }, error = function(e) NULL)
  }
  
  get_lichess_stats <- function(fen) {
    tryCatch({
      response <- GET("https://explorer.lichess.ovh/lichess", 
                      query = list(fen = fen, speeds = "blitz", ratings = "2200,2500"))
      if (status_code(response) == 200) return(content(response, "parsed"))
      return(NULL)
    }, error = function(e) NULL)
  }
  
  get_stockfish_rank <- function(move_uci, stockfish_data) {
    if (is.null(stockfish_data) || is.null(stockfish_data$pvs)) return(list(rank = NA, eval = NA))
    
    for (i in seq_along(stockfish_data$pvs)) {
      pv <- stockfish_data$pvs[[i]]
      first_move <- strsplit(pv$moves, " ")[[1]][1]
      if (first_move == move_uci) {
        eval_cp <- if (!is.null(pv$cp)) pv$cp / 100 else NA
        eval_mate <- if (!is.null(pv$mate)) paste0("M", pv$mate) else NA
        return(list(rank = i, eval = if (!is.na(eval_mate)) eval_mate else eval_cp))
      }
    }
    return(list(rank = NA, eval = NA))
  }
  
  # === CALCUL DU SCORE DE PIÈGE ===
  # On regarde la position APRÈS notre coup et on calcule quel % des réponses
  # adverses ne sont PAS parmi les 3 meilleures (proxy pour "erreurs")
  
  calculate_trap_score_for_move <- function(current_fen, move_uci) {
    tryCatch({
      # Utiliser l'API Lichess avec le paramètre "play" pour voir la position après le coup
      response <- GET(
        "https://explorer.lichess.ovh/lichess",
        query = list(
          fen = current_fen, 
          play = move_uci,
          speeds = "blitz", 
          ratings = "2200,2500"
        )
      )
      
      if (status_code(response) != 200) return(NA)
      
      next_pos <- content(response, "parsed")
      
      if (is.null(next_pos$moves) || length(next_pos$moves) == 0) return(NA)
      
      opponent_moves <- next_pos$moves
      total_games <- sum(sapply(opponent_moves, function(m) m$white + m$draws + m$black))
      
      if (total_games < 100) return(NA)  # Pas assez de données
      
      # Calculer le % de parties où l'adversaire ne joue PAS un des 3 meilleurs coups
      # Les 3 premiers coups de la DB sont généralement les meilleurs (les plus joués par les forts)
      if (length(opponent_moves) >= 3) {
        top3_games <- sum(sapply(opponent_moves[1:3], function(m) m$white + m$draws + m$black))
        top3_pct <- (top3_games / total_games) * 100
        trap_score <- round(100 - top3_pct, 0)
      } else if (length(opponent_moves) >= 1) {
        top1_games <- opponent_moves[[1]]$white + opponent_moves[[1]]$draws + opponent_moves[[1]]$black
        trap_score <- round(100 - (top1_games / total_games) * 100, 0)
      } else {
        return(NA)
      }
      
      return(max(0, trap_score))
    }, error = function(e) NA)
  }
  
  calculate_trap_scores <- function() {
    if (is.null(state$lichess_stats) || is.null(state$lichess_stats$moves)) return()
    
    moves_to_analyze <- head(state$lichess_stats$moves, 6)
    
    for (move in moves_to_analyze) {
      Sys.sleep(0.1)  # Rate limiting
      trap <- calculate_trap_score_for_move(state$fen, move$uci)
      if (!is.na(trap)) {
        state$trap_scores[[move$uci]] <- trap
      }
    }
  }
  
  # === OBSERVERS ===
  
  observeEvent(input$move_trigger, {
    req(input$fen)
    
    state$previous_fen <- state$fen
    state$previous_eval <- state$stockfish_eval
    state$fen <- input$fen
    state$last_move_san <- input$last_move_san
    
    state$stockfish_eval <- get_stockfish_analysis(state$fen)
    state$lichess_stats <- get_lichess_stats(state$fen)
    state$trap_scores <- list()
    
    calculate_trap_scores()
    chat_clear("chess_coach", session)
  })
  
  observeEvent(input$btn_undo, {
    session$sendCustomMessage("undo_move", list())
  })
  
  observeEvent(input$undo_trigger, {
    req(input$fen)
    state$fen <- input$fen
    state$last_move_san <- NULL
    state$stockfish_eval <- get_stockfish_analysis(state$fen)
    state$lichess_stats <- get_lichess_stats(state$fen)
    state$trap_scores <- list()
    calculate_trap_scores()
  })
  
  observeEvent(input$btn_reset, {
    session$sendCustomMessage("reset_board", list())
    state$fen <- "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    state$previous_fen <- NULL
    state$last_move_san <- NULL
    state$previous_eval <- NULL
    state$stockfish_eval <- NULL
    state$trap_scores <- list()
    chat_clear("chess_coach", session)
  })
  
  # === AFFICHAGE DU TABLEAU ===
  
  output$lichess_stats_display <- renderUI({
    lichess <- state$lichess_stats
    stockfish <- state$stockfish_eval
    trap_scores <- state$trap_scores
    
    if (is.null(lichess) || is.null(lichess$moves) || length(lichess$moves) == 0) {
      return(tags$p(style = "color: #999; font-style: italic;", "Pas de données"))
    }
    
    total_all_moves <- sum(sapply(lichess$moves, function(m) m$white + m$draws + m$black))
    moves_data <- lichess$moves[1:min(6, length(lichess$moves))]
    
    is_white_turn <- grepl(" w ", state$fen)
    
    # Trouver le meilleur piège
    max_trap <- 0
    best_trap_uci <- NULL
    for (move in moves_data) {
      if (!is.null(trap_scores[[move$uci]]) && !is.na(trap_scores[[move$uci]])) {
        if (trap_scores[[move$uci]] > max_trap) {
          max_trap <- trap_scores[[move$uci]]
          best_trap_uci <- move$uci
        }
      }
    }
    
    rows <- lapply(moves_data, function(move) {
      total_games <- move$white + move$draws + move$black
      pct_played <- round((total_games / total_all_moves) * 100, 1)
      
      if (is_white_turn) {
        win_pct <- round((move$white / total_games) * 100, 0)
        draw_pct <- round((move$draws / total_games) * 100, 0)
        loss_pct <- round((move$black / total_games) * 100, 0)
      } else {
        win_pct <- round((move$black / total_games) * 100, 0)
        draw_pct <- round((move$draws / total_games) * 100, 0)
        loss_pct <- round((move$white / total_games) * 100, 0)
      }
      
      result_bar <- paste0(
        "<div class='result-bar'>",
        "<div class='result-win' style='width:", win_pct, "%;'>", 
        if(win_pct > 12) paste0(win_pct, "%") else "", "</div>",
        "<div class='result-draw' style='width:", draw_pct, "%;'>",
        if(draw_pct > 12) paste0(draw_pct, "%") else "", "</div>",
        "<div class='result-loss' style='width:", loss_pct, "%;'>",
        if(loss_pct > 12) paste0(loss_pct, "%") else "", "</div>",
        "</div>"
      )
      
      sf_info <- get_stockfish_rank(move$uci, stockfish)
      
      rank_display <- if (!is.na(sf_info$rank)) {
        if (sf_info$rank == 1) "<span class='rank-1'>⭐</span>"
        else paste0("<span class='rank-", min(sf_info$rank, 3), "'>#", sf_info$rank, "</span>")
      } else "<span style='color: #999;'>-</span>"
      
      eval_display <- if (!is.na(sf_info$eval)) {
        if (is.character(sf_info$eval)) {
          paste0("<span class='positive-eval'>", sf_info$eval, "</span>")
        } else {
          eval_class <- if (is_white_turn) {
            if (sf_info$eval > 0.5) "positive-eval"
            else if (sf_info$eval < -0.5) "negative-eval"
            else "neutral-eval"
          } else {
            if (sf_info$eval < -0.5) "positive-eval"
            else if (sf_info$eval > 0.5) "negative-eval"
            else "neutral-eval"
          }
          paste0("<span class='", eval_class, "'>", sprintf("%+.2f", sf_info$eval), "</span>")
        }
      } else "<span style='color: #999;'>-</span>"
      
      # Score de piège
      trap_score <- trap_scores[[move$uci]]
      trap_display <- if (!is.null(trap_score) && !is.na(trap_score)) {
        trap_class <- if (trap_score >= 40) "trap-high"
        else if (trap_score >= 20) "trap-medium"
        else "trap-low"
        paste0("<span class='", trap_class, "'>", trap_score, "%</span>")
      } else {
        "<span style='color: #ccc;'>...</span>"
      }
      
      # Highlight meilleur piège
      row_class <- if (!is.null(best_trap_uci) && move$uci == best_trap_uci && max_trap >= 30) {
        "class='best-trap-row'"
      } else ""
      
      paste0(
        "<tr ", row_class, ">",
        "<td><strong>", move$san, "</strong></td>",
        "<td>", pct_played, "%</td>",
        "<td style='min-width: 80px;'>", result_bar, "</td>",
        "<td>", rank_display, "</td>",
        "<td>", eval_display, "</td>",
        "<td>", trap_display, "</td>",
        "</tr>"
      )
    })
    
    HTML(paste0(
      "<table class='stats-table'>",
      "<thead><tr>",
      "<th>Coup</th>",
      "<th>%</th>",
      "<th>V/N/D</th>",
      "<th>Rk</th>",
      "<th>Eval</th>",
      "<th>🎯</th>",
      "</tr></thead>",
      "<tbody>", paste(rows, collapse = ""), "</tbody>",
      "</table>"
    ))
  })
}

shinyApp(ui, server)
