#!/usr/bin/env python3
"""
Autonomous Agent Harness for long-running development tasks.
Uses the Claude Agent SDK to implement features from feature_list.json one by one.
"""

import os
import json
import argparse
import subprocess
import time
import sys
from datetime import datetime

def log(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")
    sys.stdout.flush()

def run_git(args, cwd):
    try:
        subprocess.run(["git"] + args, cwd=cwd, check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError as e:
        log(f"Git error: {e.stderr.decode()}")
        return False

class AutonomousAgent:
    def __init__(self, project_dir, model, max_iterations):
        self.project_dir = os.path.abspath(project_dir)
        self.model = model
        self.max_iterations = max_iterations
        self.feature_list_path = os.path.join(self.project_dir, "feature_list.json")
        self.progress_log_path = os.path.join(self.project_dir, "claude-progress.txt")
        self.protocol_path = os.path.join(self.project_dir, "CLAUDE.md")
        self.complete_signal_path = os.path.join(self.project_dir, ".claude", "sdk_complete.json")
        
        os.makedirs(os.path.join(self.project_dir, ".claude"), exist_ok=True)

    def load_features(self):
        if not os.path.exists(self.feature_list_path):
            log(f"Error: {self.feature_list_path} not found.")
            return None
        with open(self.feature_list_path, 'r') as f:
            return json.load(f)

    def save_features(self, features):
        with open(self.feature_list_path, 'w') as f:
            json.dump(features, f, indent=2)

    def log_progress(self, message):
        with open(self.progress_log_path, 'a') as f:
            f.write(f"\n[{datetime.now().isoformat()}] {message}\n")

    def get_next_feature(self, features):
        for feature in features:
            if not feature.get("passes", False):
                return feature
        return None

    def run(self):
        log(f"Starting autonomous agent in {self.project_dir}")
        log(f"Model: {self.model}, Max iterations: {self.max_iterations}")

        for i in range(self.max_iterations):
            log(f"--- Session {i+1}/{self.max_iterations} ---")
            
            features = self.load_features()
            if features is None: break
            
            feature = self.get_next_feature(features)
            if not feature:
                log("All features completed!")
                self.signal_completion("success")
                return

            log(f"Starting work on feature: {feature['description']}")
            
            success = self.execute_session(feature)
            
            if success:
                log(f"Feature completed successfully: {feature['description']}")
                feature["passes"] = True
                self.save_features(features)
                self.log_progress(f"Completed: {feature['description']}")
                run_git(["add", "."], self.project_dir)
                run_git(["commit", "-m", f"SDK: completed feature - {feature['description']}"], self.project_dir)
            else:
                log(f"Feature failed: {feature['description']}")
                self.log_progress(f"Failed: {feature['description']}")
            
            # Small cooldown
            time.sleep(2)

        log("Reached maximum iterations.")
        self.signal_completion("max_iterations_reached")

    def execute_session(self, feature):
        # In a real implementation, this would use the Claude Agent SDK
        # to create an agent and give it the task.
        # For this marketplace version, we'll assume the environment is set up.
        
        # This is where the actual Agent instantiation would go.
        # Since we're in a script, we'll use the SDK if available.
        try:
            from claude_agent_sdk import Agent
            
            # Read protocol
            protocol = ""
            if os.path.exists(self.protocol_path):
                with open(self.protocol_path, 'r') as f:
                    protocol = f.read()

            agent = Agent(model=self.model)
            
            prompt = f"""
I am working on a project in {self.project_dir}.
The project protocol is defined in CLAUDE.md:
{protocol}

My current task is to implement the following feature:
Description: {feature['description']}
Test Criteria: {feature.get('test', 'None provided')}

Please implement this feature, ensure it passes its tests, and let me know when you are done.
Include a brief summary of what you did.
"""
            # This is a simplified version of the loop. 
            # In a real production harness, this would handle tools and multi-turn interaction.
            # Here we let the Agent SDK handle the heavy lifting.
            result = agent.run(prompt)
            
            # Analyze result to determine success
            # For this harness, we look for a signal of completion
            return "SUCCESS" in result.upper() or "COMPLETED" in result.upper()
            
        except ImportError:
            log("Error: claude-agent-sdk not found. Simulating failure.")
            return False
        except Exception as e:
            log(f"Error during agent execution: {str(e)}")
            return False

    def signal_completion(self, reason):
        data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "reason": reason,
            "project_dir": self.project_dir
        }
        with open(self.complete_signal_path, 'w') as f:
            json.dump(data, f, indent=2)
        log(f"Completion signal written to {self.complete_signal_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-dir", required=True)
    parser.add_argument("--model", default="claude-sonnet-4-5-20250929")
    parser.add_argument("--max-iterations", type=int, default=10)
    args = parser.parse_args()

    agent = AutonomousAgent(args.project_dir, args.model, args.max_iterations)
    agent.run()
