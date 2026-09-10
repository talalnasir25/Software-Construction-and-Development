noOfSub = int(input("Enter your registered courses: "))

if noOfSub <= 0:
    print("No. of subjects invalid")
else:
    totalPoints = 0.0
    totalCreditHrs = 0.0
    for i in range(noOfSub):
        gpa = float(input(f"Enter GPA for Subject {i + 1}: "))
        creditHr = float(input(f"Enter Credit Hours for Subject {i + 1}: "))
        totalPoints += gpa * creditHr
        totalCreditHrs += creditHr

    cgpa = totalPoints / totalCreditHrs
    print(cgpa)