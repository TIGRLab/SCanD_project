import pandas as pd

def validate_events_tsv(events_df, required_cols=None):
    if required_cols is None:
        required_cols = ["onset", "duration", "trial_type"]

    # Check required columns
    for col in required_cols:
        if col not in events_df.columns:
            raise ValueError(f"Events TSV is missing required column: {col}")

    # Report additional columns
    extra_cols = [c for c in events_df.columns if c not in required_cols]
    print(f"Events task TSV contains additional column: {extra_cols}")
    # for col in events_df.columns:
    #     if col not in required_cols:
    #         print(f"Events task TSV contains additional column: {col}")

    # Check for NaNs in required columns
    for col in required_cols:
        if events_df[col].isnull().any():
            raise ValueError(f"Column '{col}' contains NaN values.")

    # Check onset and duration are numeric and non-negative
    for col in ["onset", "duration"]:
        if not pd.api.types.is_numeric_dtype(events_df[col]):
            raise TypeError(f"Column '{col}' must be numeric.")
        if (events_df[col] < 0).any():
            raise ValueError(f"Column '{col}' contains negative values.")

    # Check that trial_type is string or categorical
    if not (
        pd.api.types.is_string_dtype(events_df["trial_type"])
        or pd.api.types.is_categorical_dtype(events_df["trial_type"])
    ):
        raise TypeError("Column 'trial_type' must be string or categorical.")

    # Check if empty
    if events_df.empty:
        raise ValueError("Events TSV is empty after filtering.")

    # Report unique trial_types
    unique_trials = events_df["trial_type"].unique()
    print(f"Validation passed. Found {len(unique_trials)} unique trial types: {unique_trials}")

    return True



# This section is designed to work with CAMH dataset only!

import pandas as pd

def format_events(events_tsv: str, task: str):
    """
    Dispatch function to format events.tsv depending on task.
    """
    if task.lower() == "imob":
        return _format_imob(events_tsv)
    elif task.lower() == "nback":
        return _format_nback(events_tsv)
    else:
        raise ValueError(f"Unsupported task: {task}")

def _format_imob(event_file: str) -> pd.DataFrame:
    """
    Format EA task events TSV into standardized form.

    Args:
        event_file (str): Path to events.tsv file.

    Returns:
        pd.DataFrame: Formatted events dataframe with columns:
            onset, duration, trial_type
    """
    # Load events file
    df = pd.read_csv(event_file, sep="\t")

    # --- 1. Extract EA & Circle video blocks ---
    blocks = df[df["trial_type"].isin(["EA_block", "circle_block"])][
        ["onset", "duration", "trial_type"]
    ]

    # --- 2. Extract button press events ---
    button_press = df[df["event_type"] == "button_press"][
        ["onset", "duration", "event_type", "stim_file"]
    ]

    # Classify button presses based on stim_file
    circle_bp = button_press[button_press["stim_file"].str.contains("circles")].copy()
    ea_bp = button_press[button_press["stim_file"].str.contains("NW|AR|TA|CT|ME|HR|DH")].copy()

    # Relabel trial types
    circle_bp["trial_type"] = "circle_button_press"
    ea_bp["trial_type"] = "EA_button_press"

    # Keep consistent columns
    button_presses = pd.concat([circle_bp, ea_bp])[["onset", "duration", "trial_type"]]

    # --- 3. Merge everything ---
    events = pd.concat([blocks, button_presses]).reset_index(drop=True)

    # --- 4. Adjust onset for deleted TRs ---
    events["onset"] = events["onset"] - 8

    return events

def _format_imob(event_file: str):
    event_df = pd.read_csv(event_file, delimiter="\t")

    event = event_df[["trial_type", "onset", "duration"]]
    EA_videos = event[event_df["trial_type"] == "EA_block"]
    circle_videos = event[event_df["trial_type"] == "circle_block"]

    button_press = event_df[["onset", "event_type", "stim_file", "duration"]]
    button_press = button_press[button_press["event_type"] == "button_press"]

    circle_button_press = button_press[button_press["stim_file"].str.match("circles")]
    EA_button_press = button_press[
        button_press["stim_file"].str.match("NW|AR|TA|CT|ME|HR|DH")
    ]

    circle_button_press = circle_button_press.reset_index(drop=True)
    circle_button_press.loc[:, "event_type"] = "circle_button_press"
    EA_button_press = EA_button_press.reset_index(drop=True)
    EA_button_press.loc[:, "event_type"] = "EA_button_press"

    df_button_press = pd.concat([EA_button_press, circle_button_press])
    df_button_press.drop(["stim_file"], axis=1, inplace=True)
    df_button_press.rename(columns={"event_type": "trial_type"}, inplace=True)

    new_event_df = pd.concat([EA_videos, circle_videos, df_button_press])
    new_event_df = new_event_df.reset_index(drop=True)

    # Adjust for deleted TRs
    new_event_df.loc[:, "onset"] = new_event_df["onset"].apply(lambda x: x - 8)

    return new_event_df


def _format_nback(event_file: str):
    events_df = pd.read_csv(event_file, delimiter="\t")
    events_df = events_df[["trial_type", "onset", "duration", "correct_response", "participant_response"]]

    mask_hit = (events_df["correct_response"] == 1) & (
        events_df["participant_response"] == 1
    )
    mask_miss = (events_df["correct_response"] == 1) & (
        events_df["participant_response"] == 0
    )
    mask_false = (events_df["correct_response"] == 0) & (
        events_df["participant_response"] == 1
    )

    events_df.loc[mask_hit, "trial_type"] = (
        events_df["trial_type"].astype(str) + "_hit"
    )
    events_df.loc[mask_false, "trial_type"] = (
        events_df["trial_type"].astype(str) + "_false"
    )

    # Ugly hack to add back the TR that was dropped from CMH scan
    events_df["onset"] = events_df["onset"] + 8

    return events_df
