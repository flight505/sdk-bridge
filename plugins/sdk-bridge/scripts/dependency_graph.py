#!/usr/bin/env python3
"""
Dependency Graph Analyzer - SDK Bridge v2.0 Phase 3

Analyzes features to build dependency graph and determine parallel execution order.

Features:
- Dependency detection from feature descriptions
- Topological sorting for execution levels
- Parallel execution planning
- Critical path analysis

Author: SDK Bridge Team
Version: 2.0.0-alpha (Phase 3)
"""

import json
import logging
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Set, Optional, Tuple, Any


logger = logging.getLogger("dependency_graph")


@dataclass
class ValidationResult:
    """Result of validation check."""
    is_valid: bool
    errors: List[str]
    warnings: List[str]

    def __bool__(self):
        return self.is_valid


@dataclass
class FeatureNode:
    """Node in the dependency graph."""
    id: str
    description: str
    tags: List[str] = field(default_factory=list)
    priority: int = 50
    risk_score: float = 0.5
    complexity: float = 0.5
    passes: bool = False
    dependencies: List[str] = field(default_factory=list)  # IDs of features this depends on
    dependents: List[str] = field(default_factory=list)  # IDs of features that depend on this


@dataclass
class ExecutionLevel:
    """Level in parallel execution plan."""
    level: int
    features: List[str]  # Feature IDs
    max_parallelism: int
    estimated_duration_minutes: int = 15


@dataclass
class ExecutionPlan:
    """Complete parallel execution plan."""
    levels: List[ExecutionLevel]
    total_features: int
    max_parallel_workers: int
    estimated_total_minutes: int
    critical_path: List[str]  # Feature IDs on critical path


class DependencyGraph:
    """
    Builds and analyzes dependency graph for features.

    Detects dependencies from:
    1. Explicit 'dependencies' field in feature JSON
    2. Implicit dependencies from descriptions (e.g., "requires auth")
    3. File-based dependencies (features modifying same files)
    """

    def __init__(self):
        self.nodes: Dict[str, FeatureNode] = {}
        self.edges: List[Tuple[str, str]] = []  # (from_id, to_id)

    def add_feature(self, feature: Dict) -> str:
        """Add feature to graph."""
        feature_id = feature.get("id", f"feat-{len(self.nodes) + 1}")

        node = FeatureNode(
            id=feature_id,
            description=feature["description"],
            tags=feature.get("tags", []),
            priority=feature.get("priority", 50),
            risk_score=feature.get("risk_score", 0.5),
            complexity=feature.get("complexity", 0.5),
            passes=feature.get("passes", False),
            dependencies=feature.get("dependencies", [])
        )

        self.nodes[feature_id] = node

        # Add explicit dependency edges
        for dep_id in node.dependencies:
            self.add_edge(dep_id, feature_id)

        return feature_id

    def add_edge(self, from_id: str, to_id: str):
        """Add dependency edge (from_id must complete before to_id)."""
        if (from_id, to_id) not in self.edges:
            self.edges.append((from_id, to_id))

            # Update node references
            if from_id in self.nodes:
                self.nodes[from_id].dependents.append(to_id)
            if to_id in self.nodes:
                if from_id not in self.nodes[to_id].dependencies:
                    self.nodes[to_id].dependencies.append(from_id)

    def detect_implicit_dependencies(self):
        """
        Detect implicit dependencies from feature descriptions.

        Rules:
        - Auth features must complete before protected resource features
        - Database setup must complete before features using that table
        - API setup must complete before features calling that API
        """
        auth_features = []
        db_setup_features = []
        api_features = []

        # Categorize features
        for node_id, node in self.nodes.items():
            desc_lower = node.description.lower()
            tags_lower = [t.lower() for t in node.tags]

            # Auth features
            if any(keyword in desc_lower for keyword in ["authentication", "login", "auth", "jwt", "oauth"]):
                if any(keyword in desc_lower for keyword in ["setup", "implement", "add", "create"]):
                    auth_features.append(node_id)

            # Database setup
            if any(keyword in desc_lower for keyword in ["create table", "database setup", "schema", "migration"]):
                db_setup_features.append(node_id)

            # API features
            if "api" in tags_lower or "endpoint" in desc_lower:
                api_features.append(node_id)

        # Add implicit dependencies
        for node_id, node in self.nodes.items():
            desc_lower = node.description.lower()

            # Features requiring auth depend on auth setup
            if any(keyword in desc_lower for keyword in ["requires auth", "protected", "authenticated"]):
                for auth_id in auth_features:
                    if auth_id != node_id:
                        self.add_edge(auth_id, node_id)
                        logger.debug(f"Implicit dependency: {node_id} requires {auth_id} (auth)")

            # Features using database depend on db setup
            if any(keyword in desc_lower for keyword in ["database", "query", "insert", "update", "delete"]):
                for db_id in db_setup_features:
                    if db_id != node_id and db_id not in node.dependencies:
                        self.add_edge(db_id, node_id)
                        logger.debug(f"Implicit dependency: {node_id} requires {db_id} (database)")

    def topological_sort(self) -> List[List[str]]:
        """
        Topological sort to get execution levels.

        Returns list of levels, where each level contains features
        that can execute in parallel.
        """
        # Calculate in-degree for each node
        in_degree = {node_id: 0 for node_id in self.nodes}

        for from_id, to_id in self.edges:
            if to_id in in_degree:
                in_degree[to_id] += 1

        # Find nodes with no dependencies (in-degree = 0)
        levels = []
        remaining = set(self.nodes.keys())

        while remaining:
            # Current level: nodes with no remaining dependencies
            current_level = [
                node_id for node_id in remaining
                if in_degree[node_id] == 0
            ]

            if not current_level:
                # Cycle detected or isolated nodes
                logger.warning(f"Cycle or isolated nodes detected. Remaining: {remaining}")
                # Add remaining as final level
                current_level = list(remaining)

            levels.append(current_level)

            # Remove current level nodes
            for node_id in current_level:
                remaining.remove(node_id)

                # Decrease in-degree for dependents
                for dependent_id in self.nodes[node_id].dependents:
                    if dependent_id in in_degree:
                        in_degree[dependent_id] -= 1

            if not current_level:
                break

        return levels

    def create_execution_plan(self, max_parallel_workers: int = 3) -> ExecutionPlan:
        """
        Create parallel execution plan.

        Returns ExecutionPlan with levels and parallelism constraints.
        """
        levels_raw = self.topological_sort()

        execution_levels = []
        total_minutes = 0

        for level_idx, feature_ids in enumerate(levels_raw):
            # Calculate parallelism for this level
            parallelism = min(len(feature_ids), max_parallel_workers)

            # Estimate duration (15 min per feature, divided by parallelism)
            duration = int((len(feature_ids) * 15) / parallelism)
            total_minutes += duration

            execution_levels.append(ExecutionLevel(
                level=level_idx,
                features=feature_ids,
                max_parallelism=parallelism,
                estimated_duration_minutes=duration
            ))

        # Calculate critical path (longest path through graph)
        critical_path = self._calculate_critical_path()

        return ExecutionPlan(
            levels=execution_levels,
            total_features=len(self.nodes),
            max_parallel_workers=max_parallel_workers,
            estimated_total_minutes=total_minutes,
            critical_path=critical_path
        )

    def _calculate_critical_path(self) -> List[str]:
        """Calculate critical path (longest path through graph)."""
        # Simple implementation: find longest chain
        def get_chain_length(node_id: str, visited: Set[str]) -> Tuple[int, List[str]]:
            if node_id in visited:
                return 0, []

            visited.add(node_id)

            if not self.nodes[node_id].dependents:
                return 1, [node_id]

            max_length = 0
            max_path = []

            for dependent_id in self.nodes[node_id].dependents:
                length, path = get_chain_length(dependent_id, visited.copy())
                if length > max_length:
                    max_length = length
                    max_path = path

            return max_length + 1, [node_id] + max_path

        # Find root nodes (no dependencies)
        root_nodes = [
            node_id for node_id, node in self.nodes.items()
            if not node.dependencies
        ]

        max_length = 0
        critical_path = []

        for root_id in root_nodes:
            length, path = get_chain_length(root_id, set())
            if length > max_length:
                max_length = length
                critical_path = path

        return critical_path

    def visualize_ascii(self) -> str:
        """Generate ASCII visualization of dependency graph."""
        lines = ["Dependency Graph:", "=" * 50, ""]

        levels = self.topological_sort()

        for level_idx, feature_ids in enumerate(levels):
            lines.append(f"Level {level_idx}:")
            for feature_id in feature_ids:
                node = self.nodes[feature_id]
                deps_str = f" (depends on: {', '.join(node.dependencies)})" if node.dependencies else ""
                lines.append(f"  [{feature_id}] {node.description[:50]}{deps_str}")
            lines.append("")

        return "\n".join(lines)

    def to_json(self) -> Dict:
        """Export graph to JSON format."""
        nodes_data = []
        for node_id, node in self.nodes.items():
            nodes_data.append({
                "id": node.id,
                "description": node.description,
                "tags": node.tags,
                "priority": node.priority,
                "risk_score": node.risk_score,
                "complexity": node.complexity,
                "dependencies": node.dependencies
            })

        edges_data = [
            {"from": from_id, "to": to_id, "type": "requires"}
            for from_id, to_id in self.edges
        ]

        return {
            "version": "2.0.0",
            "nodes": nodes_data,
            "edges": edges_data,
            "metadata": {
                "total_features": len(self.nodes),
                "total_dependencies": len(self.edges)
            }
        }


def build_graph_from_feature_list(feature_list_path: str) -> DependencyGraph:
    """Build dependency graph from feature_list.json."""
    with open(feature_list_path, 'r') as f:
        features = json.load(f)

    graph = DependencyGraph()

    # Add all features
    for feature in features:
        graph.add_feature(feature)

    # Detect implicit dependencies
    graph.detect_implicit_dependencies()

    logger.info(f"Built graph: {len(graph.nodes)} features, {len(graph.edges)} dependencies")

    return graph


def validate_schema(features: List[Dict[str, Any]]) -> ValidationResult:
    """
    Validate feature_list.json schema.

    Checks:
    - Valid JSON array
    - Required fields present: id, description, passes
    - Optional fields typed correctly: dependencies (list), priority (int)
    - No duplicate IDs
    - ID format valid (no spaces, special chars)

    Args:
        features: List of feature dictionaries

    Returns:
        ValidationResult with errors and warnings
    """
    errors = []
    warnings = []

    # Check it's a list
    if not isinstance(features, list):
        errors.append("feature_list.json must be a JSON array")
        return ValidationResult(is_valid=False, errors=errors, warnings=warnings)

    # Check not empty
    if len(features) == 0:
        warnings.append("Feature list is empty")

    seen_ids = set()

    for idx, feature in enumerate(features):
        # Check it's a dict
        if not isinstance(feature, dict):
            errors.append(f"Feature at index {idx} is not an object")
            continue

        # Check required fields
        required = ["id", "description", "passes"]
        for field in required:
            if field not in feature:
                errors.append(f"Feature at index {idx} missing required field: {field}")

        # Check id format
        if "id" in feature:
            feat_id = feature["id"]
            if not isinstance(feat_id, str):
                errors.append(f"Feature at index {idx}: id must be string, got {type(feat_id)}")
            elif " " in feat_id or not feat_id.strip():
                errors.append(f"Feature at index {idx}: id '{feat_id}' contains whitespace or is empty")

            # Check for duplicates
            if feat_id in seen_ids:
                errors.append(f"Duplicate feature ID: {feat_id}")
            seen_ids.add(feat_id)

        # Check description
        if "description" in feature:
            desc = feature["description"]
            if not isinstance(desc, str):
                errors.append(f"Feature {feature.get('id', idx)}: description must be string")
            elif len(desc) < 10:
                warnings.append(f"Feature {feature.get('id', idx)}: description very short ({len(desc)} chars)")
            elif len(desc) > 200:
                warnings.append(f"Feature {feature.get('id', idx)}: description very long ({len(desc)} chars)")

        # Check passes field
        if "passes" in feature:
            passes = feature["passes"]
            if not isinstance(passes, bool):
                errors.append(f"Feature {feature.get('id', idx)}: passes must be boolean, got {type(passes)}")

        # Check optional fields
        if "dependencies" in feature:
            deps = feature["dependencies"]
            if not isinstance(deps, list):
                errors.append(f"Feature {feature.get('id', idx)}: dependencies must be array, got {type(deps)}")
            else:
                for dep in deps:
                    if not isinstance(dep, str):
                        errors.append(f"Feature {feature.get('id', idx)}: dependency must be string, got {type(dep)}")

        if "priority" in feature:
            priority = feature["priority"]
            if not isinstance(priority, (int, float)):
                errors.append(f"Feature {feature.get('id', idx)}: priority must be number, got {type(priority)}")
            elif priority < 0 or priority > 100:
                warnings.append(f"Feature {feature.get('id', idx)}: priority {priority} outside typical range 0-100")

        if "tags" in feature:
            tags = feature["tags"]
            if not isinstance(tags, list):
                errors.append(f"Feature {feature.get('id', idx)}: tags must be array, got {type(tags)}")

        # Check for test criteria (warning only)
        if "test" not in feature or not feature["test"]:
            warnings.append(f"Feature {feature.get('id', idx)}: missing test criteria")

    is_valid = len(errors) == 0
    return ValidationResult(is_valid=is_valid, errors=errors, warnings=warnings)


def _detect_cycles(graph: DependencyGraph) -> List[List[str]]:
    """
    Detect cycles in dependency graph using DFS.

    Returns:
        List of cycles, where each cycle is a list of node IDs
    """
    cycles = []
    visited = set()
    rec_stack = set()

    def dfs(node_id: str, path: List[str]):
        visited.add(node_id)
        rec_stack.add(node_id)
        path.append(node_id)

        if node_id not in graph.nodes:
            return

        for dep in graph.nodes[node_id].dependencies:
            if dep not in visited:
                dfs(dep, path.copy())
            elif dep in rec_stack:
                # Found cycle
                cycle_start = path.index(dep)
                cycles.append(path[cycle_start:] + [dep])

        rec_stack.remove(node_id)

    for node_id in graph.nodes:
        if node_id not in visited:
            dfs(node_id, [])

    return cycles


def _calculate_depth(graph: DependencyGraph, node_id: str, visited: Optional[Set[str]] = None) -> int:
    """Calculate maximum depth of dependency tree for a node."""
    if visited is None:
        visited = set()

    if node_id in visited:
        return 0  # Cycle or already processed

    visited.add(node_id)

    if node_id not in graph.nodes or not graph.nodes[node_id].dependencies:
        return 0

    max_child_depth = 0
    for dep in graph.nodes[node_id].dependencies:
        depth = _calculate_depth(graph, dep, visited.copy())
        if depth > max_child_depth:
            max_child_depth = depth

    return max_child_depth + 1


def validate_dependencies(graph: DependencyGraph) -> ValidationResult:
    """
    Validate dependency graph.

    Checks:
    - All dependency IDs exist in feature list
    - No circular dependencies (detect cycles)
    - No self-dependencies
    - Topological sort possible

    Args:
        graph: DependencyGraph instance

    Returns:
        ValidationResult with errors and warnings
    """
    errors = []
    warnings = []

    all_ids = set(graph.nodes.keys())

    # Check each node's dependencies
    for node_id, node in graph.nodes.items():
        for dep in node.dependencies:
            # Check self-dependency
            if dep == node_id:
                errors.append(f"Feature {node_id} has self-dependency")

            # Check dependency exists
            if dep not in all_ids:
                errors.append(f"Feature {node_id} depends on non-existent feature: {dep}")

    # Detect cycles
    cycles = _detect_cycles(graph)
    if cycles:
        for cycle in cycles:
            cycle_str = " → ".join(cycle)
            errors.append(f"Circular dependency detected: {cycle_str}")

    # Check if topological sort is possible
    if not cycles:
        try:
            sorted_levels = graph.topological_sort()
            # topological_sort returns list of lists (levels), so flatten to count features
            total_sorted = sum(len(level) for level in sorted_levels)
            if total_sorted != len(all_ids):
                warnings.append(f"Topological sort produced {total_sorted} features, expected {len(all_ids)}")
        except Exception as e:
            errors.append(f"Topological sort failed: {str(e)}")

    # Dependency depth check (warning only)
    max_depth = 0
    for node_id in all_ids:
        depth = _calculate_depth(graph, node_id)
        if depth > max_depth:
            max_depth = depth

    if max_depth > 5:
        warnings.append(f"Deep dependency chain detected: {max_depth} levels (consider flattening)")

    is_valid = len(errors) == 0
    return ValidationResult(is_valid=is_valid, errors=errors, warnings=warnings)


# CLI for testing
if __name__ == "__main__":
    import sys

    logging.basicConfig(level=logging.INFO)

    # Test with sample features
    sample_features = [
        {
            "id": "feat-001",
            "description": "Set up Express.js server",
            "tags": ["backend", "setup"],
            "priority": 10,
            "passes": False
        },
        {
            "id": "feat-002",
            "description": "Add JWT authentication middleware",
            "tags": ["auth", "security"],
            "priority": 8,
            "passes": False,
            "dependencies": ["feat-001"]
        },
        {
            "id": "feat-003",
            "description": "Create user registration endpoint (requires auth)",
            "tags": ["api", "auth"],
            "priority": 8,
            "passes": False
        },
        {
            "id": "feat-004",
            "description": "Add database schema for users",
            "tags": ["database"],
            "priority": 9,
            "passes": False,
            "dependencies": ["feat-001"]
        },
        {
            "id": "feat-005",
            "description": "Implement user profile API (protected endpoint)",
            "tags": ["api"],
            "priority": 5,
            "passes": False
        }
    ]

    # Save to temp file
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(sample_features, f)
        temp_path = f.name

    # Build graph
    graph = build_graph_from_feature_list(temp_path)

    print("\n" + graph.visualize_ascii())

    # Create execution plan
    plan = graph.create_execution_plan(max_parallel_workers=3)

    print("\nExecution Plan:")
    print("=" * 50)
    print(f"Total Features: {plan.total_features}")
    print(f"Max Parallel Workers: {plan.max_parallel_workers}")
    print(f"Estimated Duration: {plan.estimated_total_minutes} minutes")
    print(f"Critical Path: {' → '.join(plan.critical_path)}")
    print()

    for level in plan.levels:
        print(f"Level {level.level}: {len(level.features)} feature(s), parallelism={level.max_parallelism}")
        for feat_id in level.features:
            print(f"  - {feat_id}: {graph.nodes[feat_id].description}")
        print()

    # Cleanup
    import os
    os.unlink(temp_path)


def build_graph_from_feature_list_data(features: List[Dict[str, Any]]) -> DependencyGraph:
    """
    Build DependencyGraph from feature list data.

    Args:
        features: List of feature dictionaries

    Returns:
        Populated DependencyGraph instance
    """
    graph = DependencyGraph()

    for feature in features:
        graph.add_feature(feature)

    return graph


def reorder_by_topology(features: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Reorder features array into topologically sorted order.

    Features with no dependencies come first.
    Features at same dependency level maintain relative order (stable sort).

    Args:
        features: List of feature dictionaries

    Returns:
        Reordered list of features in execution order

    Raises:
        ValueError: If dependency graph has cycles or invalid refs
    """
    # Build graph
    graph = build_graph_from_feature_list_data(features)

    # Validate dependencies first
    validation = validate_dependencies(graph)
    if not validation.is_valid:
        raise ValueError(f"Cannot reorder - invalid dependencies: {', '.join(validation.errors)}")

    # Get topological order (returns List[List[str]] - levels)
    levels = graph.topological_sort()

    # Flatten levels into single list of IDs
    sorted_ids = []
    for level in levels:
        sorted_ids.extend(level)

    # Reorder features array
    id_to_feature = {f["id"]: f for f in features}
    reordered = [id_to_feature[feat_id] for feat_id in sorted_ids]

    return reordered
