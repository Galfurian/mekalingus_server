import json
import argparse
import sys


# ----------------------------------------------------------------------
# Global style specification for ALL generated icons
# ----------------------------------------------------------------------

ICON_STYLE = (
    "top-down mech game UI icon, "
    "orthographic view, centered subject, "
    "minimalist hard-surface sci-fi design, "
    "clean silhouette readable at small size, "
    "flat shading with subtle highlights, "
    "single light source from top-left, "
    "limited color palette, "
    "dark metal and industrial colors, "
    "2px dark outline, "
    "no text, no background, "
    "transparent background, "
    "no hand-held items, "
    "128x128 icon,"
    "square border around each icon"
)


def generate_prompt(
    entity_id,
    entity_data,
    entity_type,
):
    """
    Determine object type and generate a consistent AI icon prompt.
    """

    entity_name = entity_data["name"]
    appearance = entity_data["appearance"]

    # Mek
    if entity_type == "mech":
        size = entity_data["size"].lower()
        subject = f"{size.upper()}-class combat mech '{entity_name}'"
    # Weapon
    elif entity_type == "weapons":
        slot_type = entity_data["slot"].lower()
        subject = f"{slot_type} sci-fi mech-mounted weapon module '{entity_name}'"
    # Utility
    elif entity_type == "utilities":
        slot_type = entity_data["slot"].lower()
        subject = f"{slot_type} sci-fi mech-mounted utility module '{entity_name}'"
    # Extraction
    elif entity_type == "structure":
        size = entity_data["size"].lower()
        structure_type = entity_data["structure_type"].lower()
        structure_sub_type = entity_data["structure_sub_type"].lower()
        subject = f"{size} {structure_type} ({structure_sub_type}) sci-fi structure '{entity_name}'"
    else:
        subject = f"sci-fi entity '{entity_name}'"

    # prompt = f"{entity_name} ({entity_id})\n{ICON_STYLE}, {subject}. {appearance}"
    prompt = f"{entity_name} ({entity_id})\n{subject}. {appearance}"
    return prompt


def main():
    parser = argparse.ArgumentParser(
        description="Generate consistent AI icon prompts from game JSON data."
    )

    parser.add_argument(
        "input_file",
        type=str,
        help="Path to the JSON file to process.",
    )
    parser.add_argument(
        "entity_type",
        type=str,
        choices=[
            "mech",
            "weapons",
            "utilities",
            "structure",
        ],
    )

    args = parser.parse_args()

    try:
        with open(args.input_file, "r", encoding="utf-8") as f:
            data = json.load(f)

    except FileNotFoundError:
        print(f"Error: The file '{args.input_file}' was not found.")
        sys.exit(1)

    except json.JSONDecodeError:
        print(f"Error: The file '{args.input_file}' is not valid JSON.")
        sys.exit(1)

    print(f"--- Generating Consistent Icon Prompts for {args.input_file} ---\n")

    for entity_id, entity_data in data.items():

        prompt = generate_prompt(entity_id, entity_data, args.entity_type)

        print(prompt)
        print()
    print(f"Use this style: {ICON_STYLE}.")
    print()


if __name__ == "__main__":
    main()
