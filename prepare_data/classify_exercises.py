from langchain.output_parsers import StructuredOutputParser, ResponseSchema
from langchain.prompts import ChatPromptTemplate, HumanMessagePromptTemplate
from langchain.llms import OpenAI
from langchain.chat_models import ChatOpenAI
import pandas as pd
import json
import os
from dotenv import load_dotenv
from math import ceil
import time


class ExerciseClassifier:
    """
    A class to classify exercises into muscle groups using the LangChain API.
    """

    def __init__(self, api_key, temperature=0, max_tokens=1000):
        """
        Initialize the classifier with the API key and chat model parameters.
        """
        load_dotenv(".env")
        self.chat_model = ChatOpenAI(
            temperature=temperature, openai_api_key=api_key, max_tokens=max_tokens
        )
        self.response_schemas = [
            ResponseSchema(
                name="exercise_name", description="The name of the exercise."
            ),
            ResponseSchema(
                name="muscle_groups",
                description="Muscle groups matched to the exercise.",
            ),
            ResponseSchema(
                name="match_score", description="Match score between 0-100."
            ),
        ]
        self.output_parser = StructuredOutputParser.from_response_schemas(
            self.response_schemas
        )
        self.prompt_template = self.create_prompt_template()
        print("ExerciseClassifier initialized.")

    def create_prompt_template(self):
        """
        Creates the prompt template to be used for the chat model.
        """
        format_instructions = self.output_parser.get_format_instructions()
        template = """
        You will be given a series of exercise names from a user.
        Find the best corresponding match on the list of muscle groups.

        The closest match will be the one with the closest semantic meaning. Not just string similarity.

        When classifying, try to be more rather than less inclusive.
        For example, a bench press should be classified with not only chest and triceps, but also front delt. Exercises that involve significant grip strength (e.g. deadlift variations) should include forearms.
        However, don't be infinitely generous. Leg presses and squats, for instance, should use quads and glutes, but not calves or hamstrings.
        Apply the same principle when classifying all exercises.

        {format_instructions}

        Wrap your final output with closed and open brackets (a list of json objects)

        exercise_names INPUT:
        {exercise_names}

        MUSCLE GROUPS:
        {muscle_groups}

        YOUR RESPONSE:
        """
        prompt = ChatPromptTemplate(
            messages=[HumanMessagePromptTemplate.from_template(template)],
            input_variables=["exercise_names", "muscle_groups"],
            partial_variables={"format_instructions": format_instructions},
        )
        return prompt

    def parse_chat_output(self, output):
        """
        Parses the chat model output into a DataFrame.
        """
        try:
            json_string = (
                output.content.split("```json")[1].strip().rstrip("```")
                if "```json" in output.content
                else output.content
            )
            print("Output parsed successfully.")
            return pd.DataFrame(json.loads(json_string))
        except json.JSONDecodeError as e:
            print(f"JSONDecodeError occurred: {e}")
            return pd.DataFrame()

    def make_chunked_api_calls(self, exercise_names, muscle_groups, chunk_size):
        """
        Makes chunked API calls to classify exercises and collects responses.
        """
        all_responses = []
        num_chunks = ceil(len(exercise_names) / chunk_size)
        for i in range(num_chunks):
            start = time.time()
            exercise_chunk_str = ", ".join(
                exercise_names[i * chunk_size : (i + 1) * chunk_size]
            )
            print(f"Processing chunk {i+1}/{num_chunks}...")
            _input = self.prompt_template.format_prompt(
                exercise_names=exercise_chunk_str, muscle_groups=muscle_groups
            )
            output = self.chat_model(_input.to_messages())
            all_responses.append(self.parse_chat_output(output))
            print(
                f"Chunk {i+1}/{num_chunks} processed in {time.time() - start:.2f} seconds."
            )
        return pd.concat(all_responses, ignore_index=True)

    def merge_and_cleanup(self, final_response, muscle_groups_data):
        """
        Merges response with muscle group data and cleans up DataFrame.
        """
        print("Merging response with muscle group data...")
        final_response["muscle_groups_list"] = final_response[
            "muscle_groups"
        ].str.split(", ")
        exploded_df = final_response.explode("muscle_groups_list").reset_index(
            drop=True
        )
        merged_df = pd.merge(
            exploded_df,
            muscle_groups_data,
            left_on="muscle_groups_list",
            right_on="Muscle_Group",
            how="left",
        )
        print("Data merged successfully.")
        return merged_df

    @staticmethod
    def majority_or_unclear(s):
        """
        Determines the majority classification or returns 'Unclear'.
        """
        modes = s.mode()
        return modes.iloc[0] if len(modes) == 1 else "Unclear"

    def group_and_aggregate(self, merged_df):
        """
        Groups DataFrame by exercise name and aggregates classifications.
        """
        print("Grouping and aggregating data...")
        return (
            merged_df.groupby("exercise_name")
            .agg(
                {
                    "Anterior_Posterior": self.majority_or_unclear,
                    "Push_Pull_Legs": self.majority_or_unclear,
                }
            )
            .reset_index()
        )

    def classify(self, data_path, muscle_groups_data):
        """
        Classifies exercises and saves results to CSV.
        """
        print("Starting classification process...")
        muscle_groups = ", ".join(muscle_groups_data["Muscle_Group"].values)
        weightlifting_data = pd.read_csv(data_path)
        exercise_names = weightlifting_data["exercise_name"].unique()

        final_response = self.make_chunked_api_calls(
            exercise_names, muscle_groups, chunk_size=10
        )
        merged_df = self.merge_and_cleanup(final_response, muscle_groups_data)
        df_grouped = self.group_and_aggregate(merged_df)

        # Merge the grouped data back to the merged data
        df_final = pd.merge(
            merged_df.drop(columns=["Anterior_Posterior", "Push_Pull_Legs"]),
            df_grouped,
            on="exercise_name",
            how="left",
        )

        # Now drop the 'muscle_groups_list' column after it's no longer needed
        df_final = df_final.drop(columns=["muscle_groups_list"])

        output_path = "data/exercise_classifications.csv"
        df_final.to_csv(output_path, index=False)
        print(f"Classification completed. Results saved to {output_path}")

        return df_final


# Usage
load_dotenv(".env")
api_key = os.getenv("OPENAI_API_KEY")
classifier = ExerciseClassifier(api_key)
muscle_groups_data = {
    "Muscle_Group": [
        "chest",
        "front delt",
        "side delt",
        "triceps",
        "abs",
        "obliques",  # Push
        "trapezius",
        "lats",
        "rear delt",
        "biceps",
        "forearms",
        "lower back",
        "rhomboids",
        "neck",  # Pull
        "quads",
        "calves",
        "adductors",
        "hamstrings",
        "glutes",
        "abductors",  # Legs
    ],
    "Anterior_Posterior": [
        "anterior",
        "anterior",
        "anterior",
        "anterior",
        "anterior",
        "anterior",  # Push
        "posterior",
        "posterior",
        "posterior",
        "posterior",
        "posterior",
        "posterior",
        "posterior",
        "posterior",  # Pull
        "anterior",
        "anterior",
        "anterior",
        "posterior",
        "posterior",
        "posterior",  # Legs
    ],
    "Push_Pull_Legs": [
        "push",
        "push",
        "push",
        "push",
        "push",
        "push",  # Push
        "pull",
        "pull",
        "pull",
        "pull",
        "pull",
        "pull",
        "pull",
        "pull",  # Pull
        "legs",
        "legs",
        "legs",
        "legs",
        "legs",
        "legs",  # Legs
    ],
}
muscle_groups_data = pd.DataFrame(muscle_groups_data)
classified_exercises = classifier.classify(
    "data/weightlifting_data.csv", muscle_groups_data
)
