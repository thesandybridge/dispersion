import {
    useMutation,
    useQuery,
    useQueryClient,
} from "@tanstack/react-query";
import {
    createClub,
    deleteClub,
    listClubs,
    updateClub,
} from "../db/clubs";
import {
    createSession,
    deleteSession,
    listSessions,
} from "../db/sessions";
import {
    createShot,
    deleteShot,
    listShotsByClub,
    listShotsBySession,
    shotCounts,
} from "../db/shots";
import { listAllShots } from "../db/shotsAll";
import {
    createFaceStrike,
    deleteFaceStrike,
    listFaceStrikesByClub,
} from "../db/faceStrikes";
import {
    createTestClub,
    deleteTestClub,
    listTestClubs,
    updateTestClub,
} from "../db/testClubs";
import type { Club, NewClub, ShotOutcomeTag } from "../types";

const clubsKey = ["clubs"] as const;
const sessionsKey = ["sessions"] as const;
const shotCountsKey = ["shotCounts"] as const;
const shotsBySessionKey = (id: string) => ["shots", "session", id] as const;
const shotsByClubKey = (id: string) => ["shots", "club", id] as const;

export function useClubs() {
    return useQuery({ queryKey: clubsKey, queryFn: listClubs });
}

export function useCreateClub() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: (input: Omit<NewClub, "createdAt">) => createClub(input),
        onSuccess: () => qc.invalidateQueries({ queryKey: clubsKey }),
    });
}

export function useUpdateClub() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: ({
            id,
            patch,
        }: {
            id: string;
            patch: Pick<Club, "name" | "carryYards" | "carrySd" | "lateralSd">;
        }) => updateClub(id, patch),
        onSuccess: () => qc.invalidateQueries({ queryKey: clubsKey }),
    });
}

export function useDeleteClub() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: (id: string) => deleteClub(id),
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: clubsKey });
            qc.invalidateQueries({ queryKey: shotCountsKey });
            qc.invalidateQueries({ queryKey: ["shots"] });
            qc.invalidateQueries({ queryKey: ["shots", "all"] });
        },
    });
}

export function useDeleteSession() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: (id: string) => deleteSession(id),
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: sessionsKey });
            qc.invalidateQueries({ queryKey: shotCountsKey });
            qc.invalidateQueries({ queryKey: ["shots"] });
            qc.invalidateQueries({ queryKey: ["shots", "all"] });
        },
    });
}

export function useDeleteShot() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: (id: string) => deleteShot(id),
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: shotCountsKey });
            qc.invalidateQueries({ queryKey: ["shots"] });
            qc.invalidateQueries({ queryKey: ["shots", "all"] });
        },
    });
}

const faceStrikesKey = (clubId: string) =>
    ["faceStrikes", clubId] as const;

export function useFaceStrikes(clubId: string | null) {
    return useQuery({
        queryKey: faceStrikesKey(clubId ?? "_"),
        queryFn: () => (clubId ? listFaceStrikesByClub(clubId) : []),
        enabled: !!clubId,
    });
}

export function useCreateFaceStrike() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: createFaceStrike,
        onSuccess: (strike) =>
            qc.invalidateQueries({ queryKey: faceStrikesKey(strike.clubId) }),
    });
}

const testClubsKey = ["testClubs"] as const;

export function useTestClubs() {
    return useQuery({ queryKey: testClubsKey, queryFn: listTestClubs });
}

export function useCreateTestClub() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: createTestClub,
        onSuccess: () =>
            qc.invalidateQueries({ queryKey: testClubsKey }),
    });
}

export function useUpdateTestClub() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: ({
            id,
            patch,
        }: {
            id: string;
            patch: Parameters<typeof updateTestClub>[1];
        }) => updateTestClub(id, patch),
        onSuccess: () =>
            qc.invalidateQueries({ queryKey: testClubsKey }),
    });
}

export function useDeleteTestClub() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: (id: string) => deleteTestClub(id),
        onSuccess: () =>
            qc.invalidateQueries({ queryKey: testClubsKey }),
    });
}

export function useDeleteFaceStrike(clubId: string) {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: (id: string) => deleteFaceStrike(id),
        onSuccess: () =>
            qc.invalidateQueries({ queryKey: faceStrikesKey(clubId) }),
    });
}

export function useSessions() {
    return useQuery({ queryKey: sessionsKey, queryFn: () => listSessions() });
}

export function useCreateSession() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: createSession,
        onSuccess: () => qc.invalidateQueries({ queryKey: sessionsKey }),
    });
}

export function useShotsBySession(sessionId: string | null) {
    return useQuery({
        queryKey: shotsBySessionKey(sessionId ?? "_"),
        queryFn: () => (sessionId ? listShotsBySession(sessionId) : []),
        enabled: !!sessionId,
    });
}

export function useShotsByClub(clubId: string | null) {
    return useQuery({
        queryKey: shotsByClubKey(clubId ?? "_"),
        queryFn: () => (clubId ? listShotsByClub(clubId) : []),
        enabled: !!clubId,
    });
}

export function useShotCounts() {
    return useQuery({ queryKey: shotCountsKey, queryFn: shotCounts });
}

export function useAllShots() {
    return useQuery({
        queryKey: ["shots", "all"] as const,
        queryFn: () => listAllShots(),
        staleTime: 60_000,
    });
}

export function useCreateShot() {
    const qc = useQueryClient();
    return useMutation({
        mutationFn: (input: {
            id: string;
            sessionId: string;
            clubId: string;
            targetDistanceYards: number;
            longDelta: number;
            latDelta: number;
            outcomes?: ShotOutcomeTag[];
        }) => createShot(input),
        onSuccess: (shot) => {
            qc.invalidateQueries({ queryKey: shotsBySessionKey(shot.sessionId) });
            qc.invalidateQueries({ queryKey: shotsByClubKey(shot.clubId) });
            qc.invalidateQueries({ queryKey: shotCountsKey });
        },
    });
}
