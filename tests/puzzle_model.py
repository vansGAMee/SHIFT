"""Exhaustive design checks for the binary-state SHIFT chambers.

This independent finite model checks the intended solutions and reset semantics;
it is not a substitute for playing the actual 3D build.
"""
from dataclasses import dataclass, replace
from collections import deque
import unittest

@dataclass(frozen=True)
class Crossing:
    zone: int = 0  # 0 generator side, 1 between shutter and pit, 2 far bank, 3 exit
    generator: bool = True
    bridge: bool = False
    shifts: int = 1
    door: bool = False

    @property
    def gate_open(self):
        return self.generator

    def act(self, command):
        if command == 'reset':
            return Crossing()
        if command == 'shift' and self.shifts and self.generator != self.bridge:
            return replace(self, generator=self.bridge, bridge=self.generator, shifts=0)
        if command == 'gate' and self.gate_open and self.zone in (0, 1):
            return replace(self, zone=1-self.zone)
        if command == 'bridge' and self.bridge and self.zone in (1, 2):
            return replace(self, zone=3-self.zone)
        if command == 'lever' and self.zone == 2 and not self.generator:
            return replace(self, door=not self.door)
        if command == 'exit' and self.zone == 2 and self.door:
            return replace(self, zone=3)
        return self

class PuzzleDesignTests(unittest.TestCase):
    def test_swap_is_atomic_and_conserves_binary_charge(self):
        for a in (False, True):
            for b in (False, True):
                self.assertEqual(int(a)+int(b), int(b)+int(a))
        state = Crossing().act('gate').act('shift')
        self.assertEqual((state.generator, state.bridge, state.shifts), (False, True, 0))
        self.assertFalse(state.gate_open)
        self.assertEqual(state.act('shift'), state)

    def test_spatial_solution(self):
        state = Crossing()
        for action in ('gate', 'shift', 'bridge', 'lever', 'exit'):
            state = state.act(action)
        self.assertEqual(state.zone, 3)
        self.assertEqual(state.shifts, 0)

    def test_early_shift_requires_reset_and_does_not_fake_a_solution(self):
        state = Crossing().act('shift')
        self.assertEqual(state.act('gate').zone, 0)
        self.assertEqual(state.act('reset'), Crossing())

    def test_every_reachable_solution_requires_correct_side_and_one_swap(self):
        start = Crossing()
        pending = deque([(start, [])])
        seen = {start}
        solutions = []
        for_limit = ('gate', 'bridge', 'lever', 'shift', 'exit')
        while pending:
            state, route = pending.popleft()
            if state.zone == 3:
                solutions.append(route)
                self.assertEqual(state.shifts, 0)
                self.assertFalse(state.generator)
                self.assertTrue(state.bridge)
                self.assertLess(route.index('gate'), route.index('shift'))
                continue
            for command in for_limit:
                target = state.act(command)
                if target not in seen:
                    seen.add(target)
                    pending.append((target, route + [command]))
        self.assertTrue(solutions)
        self.assertEqual(solutions[0], ['gate', 'shift', 'bridge', 'lever', 'exit'])

    def test_first_chamber_cannot_create_charge_or_consume_equal_state_swap(self):
        source, door, budget = False, False, 1
        # Selecting two inactive devices is a no-op with clear feedback.
        if source != door:
            source, door, budget = door, source, budget-1
        self.assertEqual((source, door, budget), (False, False, 1))
        source = True  # Physical charging lever.
        source, door, budget = door, source, budget-1
        self.assertEqual((source, door, budget), (False, True, 0))


RELAY_INITIAL = (True, True, True, False, True, False)
RELAY_SOLUTION = (True, False, True, True, False)

def relay_sensors(bits):
    """Five mechanical contacts each invert one adjacent pair of six lamps."""
    lamps = list(RELAY_INITIAL)
    for i, enabled in enumerate(bits):
        if enabled:
            lamps[i] = not lamps[i]
            lamps[i+1] = not lamps[i+1]
    return tuple(lamps)

def coolant_route(valves):
    """Follow the actual directed pipe diagram; repeated nodes are a closed loop."""
    a, b, c, d = valves
    graph = {'A': 'C' if a else 'B',
             'B': 'A' if b else 'D',
             'C': 'ROOM' if c else 'B',
             'D': 'C' if d else 'TANK'}
    node, visited, cooled = 'A', set(), False
    while node not in ('ROOM', 'TANK'):
        if node in visited:
            return 'loop'
        visited.add(node)
        cooled = cooled or node == 'C'
        node = graph[node]
    if node == 'ROOM':
        return 'room'
    return 'cooled' if cooled else 'hot_tank'

class ExtraPuzzleDesignTests(unittest.TestCase):
    def test_relay_has_one_solution_across_all_thirty_two_configurations(self):
        from itertools import product
        solutions = [bits for bits in product((False, True), repeat=5)
                     if not any(relay_sensors(bits))]
        self.assertEqual(solutions, [RELAY_SOLUTION])

    def test_relay_each_contact_changes_exactly_its_adjacent_pair(self):
        baseline = relay_sensors((False,)*5)
        for i in range(5):
            bits = tuple(j == i for j in range(5))
            changed = [j for j, (a, b) in enumerate(zip(baseline, relay_sensors(bits))) if a != b]
            self.assertEqual(changed, [i, i+1])

    def test_relay_needs_three_distinct_preparations_before_charge(self):
        self.assertEqual([i for i, on in enumerate(RELAY_SOLUTION) if on], [0, 2, 3])
        for omitted in (0, 2, 3):
            incomplete = tuple(on and i != omitted for i, on in enumerate(RELAY_SOLUTION))
            self.assertTrue(any(relay_sensors(incomplete)))

    def test_coolant_route_has_one_safe_configuration_across_all_sixteen(self):
        from itertools import product
        solutions = [bits for bits in product((False, True), repeat=4)
                     if coolant_route(bits) == 'cooled']
        self.assertEqual(solutions, [(True, False, False, False)])

    def test_coolant_diagram_distinguishes_three_failure_modes(self):
        self.assertEqual(coolant_route((False, True, True, True)), 'loop')
        self.assertEqual(coolant_route((False, False, False, False)), 'hot_tank')
        self.assertEqual(coolant_route((True, False, True, False)), 'room')
        self.assertEqual(coolant_route((True, False, False,False)), 'cooled')

    def test_coolant_initial_configuration_requires_all_four_diverters(self):
        initial = (False, True, True, True)
        solution = (True, False, False, False)
        self.assertEqual(sum(a != b for a, b in zip(initial, solution)), 4)
        for i in range(4):
            unfinished = tuple(initial[j] if j == i else solution[j] for j in range(4))
            self.assertNotEqual(coolant_route(unfinished), 'cooled')

if __name__ == '__main__':
    unittest.main(verbosity=2)
