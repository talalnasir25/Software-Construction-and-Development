grades = {"A": 4.0, "B": 3.0, "C": 2.0, "D": 1.0, "F": 0.0}

n = int(input("Number of subjects: "))
total_credits = 0
total_points = 0

for i in range(n):
    grade = input(f"Grade for subject {i+1} (A/B/C/D/F): ").upper()
    credit = float(input(f"Credit hours for subject {i+1}: "))
    total_points += grades[grade] * credit
    total_credits += credit

cgpa = total_points / total_credits
print(f"\nCGPA: {cgpa:.2f}")
